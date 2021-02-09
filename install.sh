#!/usr/bin/env bash
set -e          # Fail in case of error
set -o nounset  # Fail if undefined variables are used
set -o pipefail # Fail if one of the piped commands fails

#
# Usage:
#   curl ... | ENV_VAR=... bash
#       or
#   ENV_VAR=... ./install.sh
#
# Example:
#   Installing LiqoAgent configuring the version:
#     curl ... | LIQOAGENT_VERSION="0.1" bash
#   Uninstalling LiqoAgent:
#     curl ... | bash -s -- --uninstall
#
# Arguments:
#   - --uninstall:        uninstall Liqo from your cluster
#
# Environment variables:
#
#   - KUBECONFIG
#     the KUBECONFIG file used to interact with a Liqo cluster (defaults to ~/.kube/config).
#
#   - LIQOAGENT_REPO
#     the repository of LiqoAgent to install. Defaults to "liqotech/liqo-agent", but can be changed in case of forks.
#
#   - LIQOAGENT_VERSION
#     the released version of LiqoAgent to install. Defaults to the latest one.
#

# This script has been edited starting from the Liqo installer (https://github.com/liqotech/liqo).

EXIT_SUCCESS=0
EXIT_FAILURE=1

LIQOAGENT_REPO_DEFAULT="liqotech/liqo-agent"

#--------------
#--- OUTPUT ---
#--------------

function setup_colors() {
	# Only use colors if connected to a terminal
	if [ -t 1 ]; then
		RED=$(printf '\033[31m')
		GREEN=$(printf '\033[32m')
		YELLOW=$(printf '\033[33m')
		BLUE=$(printf '\033[34m')
		BOLD=$(printf '\033[1m')
		RESET=$(printf '\033[m')
	else
		RED=""
		GREEN=""
		YELLOW=""
		BLUE=""
		BOLD=""
		RESET=""
	fi
}

function print_logo() {
	# ASCII Art: https://patorjk.com/software/taag/#p=display&f=Big%20Money-ne&t=LiqoAgent
	echo -n "${BLUE}${BOLD}"
	cat <<-'EOF'
		
		
			     /$$       /$$                      /$$$$$$                                  /$$
			    | $$      |__/                     /$$__  $$                                | $$
			    | $$       /$$  /$$$$$$   /$$$$$$ | $$  \ $$  /$$$$$$   /$$$$$$  /$$$$$$$  /$$$$$$
			    | $$      | $$ /$$__  $$ /$$__  $$| $$$$$$$$ /$$__  $$ /$$__  $$| $$__  $$|_  $$_/
			    | $$      | $$| $$  \ $$| $$  \ $$| $$__  $$| $$  \ $$| $$$$$$$$| $$  \ $$  | $$
			    | $$      | $$| $$  | $$| $$  | $$| $$  | $$| $$  | $$| $$_____/| $$  | $$  | $$ /$$
			    | $$$$$$$$| $$|  $$$$$$$|  $$$$$$/| $$  | $$|  $$$$$$$|  $$$$$$$| $$  | $$  |  $$$$/
			    |________/|__/ \____  $$ \______/ |__/  |__/ \____  $$ \_______/|__/  |__/   \___/
			                        | $$                     /$$  \ $$
			                        | $$                    |  $$$$$$/
			                        |__/                     \______/
		
		
	EOF
	echo -n "${RESET}"
}

function info() {
	echo "${GREEN}${BOLD}$1${RESET} ${*:2}"
}

function warn() {
	echo "${YELLOW}${BOLD}$1${RESET} ${*:2}" >&2
}

function fatal() {
	echo "${RED}${BOLD}$1 [FATAL]${RESET} ${*:2}" >&2
	exit ${EXIT_FAILURE}
}

function help() {
	cat <<-EOF
		${BLUE}${BOLD}Install LiqoAgent on your device${RESET}
		  ${BOLD}Usage: $0 [options]
		
		${BLUE}${BOLD}Options:${RESET}
		  ${BOLD}--uninstall${RESET}:        uninstall LiqoAgent from your device
		
		  ${BOLD}-h, --help${RESET}:         display this help
		
		${BLUE}${BOLD}Environment variables:${RESET}
		  ${BOLD}LIQOAGENT_REPO{RESET}:      the repository of LiqoAgent to install. Defaults to "liqotech/liqo-agent", but can be changed in case of forks.
		
		  ${BOLD}LIQOAGENT_VERSION{RESET}:   the released version of LiqoAgent to install (e.g. "v0.1"). Defaults to the latest one.
		
		  ${BOLD}KUBECONFIG${RESET}:         the KUBECONFIG file used to interact with the Liqo cluster. Defaults to ~/.kube/config.
	EOF
}

#---------------------
#--- GENERAL SETUP ---
#---------------------

function command_exists() {
	command -v "$1" >/dev/null 2>&1
}

function setup_arch_and_os() {
	ARCH=$(uname -m)
	case $ARCH in
		armv5*) ARCH="armv5" ;;
		armv6*) ARCH="armv6" ;;
		armv7*) ARCH="arm" ;;
		aarch64) ARCH="arm64" ;;
		x86) ARCH="386" ;;
		x86_64) ARCH="amd64" ;;
		i686) ARCH="386" ;;
		i386) ARCH="386" ;;
		*)
			fatal "[PRE-FLIGHT] [REQUIREMENTS]" "unknown '${ARCH}' architecture"
			return
			;;
	esac

	OS=$(uname | tr '[:upper:]' '[:lower:]')
	case "$OS" in
		"darwin"*) setup_darwin_package ;;
			# Minimalist GNU for Windows
		"mingw"*) OS='windows' ;;
	esac

	# borrow to helm install script: https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
	local supported="linux-amd64"
	if ! echo "${supported}" | grep -q "${OS}-${ARCH}"; then
		fatal "[PRE-FLIGHT] [REQUIREMENTS]" "System '${OS}-${ARCH}' not supported."
	fi
}

function setup_tmpdir() {
	AGENT_DIR=$(mktemp -d -t liqo_agent-install.XXXXXXXXXX)
	AGENT_BIN_DOWNLOAD_DIR="${AGENT_DIR}/bin"
	AGENT_REPO_DOWNLOAD_DIR="${AGENT_DIR}/repo"
	AGENT_ASSETS_DIR="${AGENT_REPO_DOWNLOAD_DIR}/assets/tray-agent"
	AGENT_INSTALL_LINUX_DIR="${AGENT_ASSETS_DIR}/install/linux"
	mkdir --parent "${AGENT_BIN_DOWNLOAD_DIR}"
	mkdir --parent "${AGENT_REPO_DOWNLOAD_DIR}"

	cleanup() {
		local CODE=$?

		# Do not trigger errors again if something goes wrong
		set +e
		trap - EXIT

		rm -rf "${AGENT_DIR}"
		exit ${CODE}
	}
	trap cleanup INT EXIT
}

function setup_downloader() {
	if command_exists "curl"; then
		DOWNLOADER="curl"
	elif command_exists "wget"; then
		DOWNLOADER="wget"
	else
		fatal "[PRE-FLIGHT] [INSTALL]" "Cannot find neither 'curl' nor 'wget' to download files"
	fi

	info "[PRE-FLIGHT] [INSTALL]" "Using ${DOWNLOADER} to download files"
}

function download() {
	[ $# -eq 1 ] || fatal "[PRE-FLIGHT] [DOWNLOAD]" "Internal error: incorrect parameters"

	case ${DOWNLOADER:-} in
		curl)
			curl --output - --silent --fail --location "$1" ||
				fatal "[PRE-FLIGHT] [DOWNLOAD]" "Failed downloading $1"
			;;
		wget)
			wget --quiet --output-document=- "$1" ||
				fatal "[PRE-FLIGHT] [DOWNLOAD]" "Failed downloading $1"
			;;
		*)
			fatal "[PRE-FLIGHT] [DOWNLOAD]" "Internal error: incorrect downloader"
			;;
	esac
}

## macOs helpers
function setup_darwin_package() {
	info "[PRE-FLIGHT] [REQUIREMENTS]" "Checking necessary GNU-tools (e.g. getopts, grep) are installed"
	command_exists "brew" || fatal "[PRE-FLIGHT] [REQUIREMENTS]" "This version requires 'brew' (https://docs.brew.sh/Installation)"

	darwin_install_gnu_tool "coreutils" "/usr/local/opt/coreutils/libexec/gnubin"
	darwin_install_gnu_tool "grep" "/usr/local/opt/grep/libexec/gnubin"
	darwin_install_gnu_tool "gnu-getopt" "/usr/local/opt/gnu-getopt/bin"
	darwin_install_gnu_tool "gnu-tar" "/usr/local/opt/gnu-tar/libexec/gnubin"
}

function darwin_install_gnu_tool() {
	local PACKAGE=$1
	local BINARY_PATH=$2

	if ! brew list "${PACKAGE}" >/dev/null 2>&1; then
		info "[PRE-FLIGHT] [REQUIREMENTS-INSTALL]" "package '${PACKAGE}' is not installed. Do you want to install it ?"
		select yn in "Yes" "No"; do
			case $yn in
				Yes)
					brew install "${PACKAGE}"
					info "[PRE-FLIGHT] [REQUIREMENTS-INSTALL]" "package '${PACKAGE}' installed"
					break
					;;
				No) fatal "[PRE-FLIGHT] [REQUIREMENTS-INSTALL] package '${PACKAGE}' is required. Aborting" ;;
				*) warn "[PRE-FLIGHT] [REQUIREMENTS-INSTALL]" "Invalid option" ;;
			esac
			# select reads input from stdin. If the script is piped (e.g. curl'ed), the stdin is the pipe and therefore the select does not work.
			# To avoid this problem we read input from tty
		done </dev/tty
	fi
	info "[PRE-FLIGHT] [REQUIREMENTS-INSTALL]" "Adding GNU tools by '${PACKAGE}' to PATH"
	export PATH="${BINARY_PATH}:$PATH"
}
##

# INPUT

function parse_arguments() {
	# Call getopt to validate the provided input.
	local ERROR_STR="${RED}${BOLD}[PRE-FLIGHT] [FATAL]${RESET}"
	OPTIONS=$(getopt --options h --longoptions help,uninstall --name "${ERROR_STR}" -- "$@") ||
		exit ${EXIT_FAILURE}

	INSTALL_LIQO_AGENT=true

	eval set -- "$OPTIONS"
	unset OPTIONS

	while true; do
		case "$1" in
			--help | -h)
				help
				exit ${EXIT_SUCCESS}
				;;

			--uninstall)
				INSTALL_LIQO_AGENT=false
				;;

			--)
				shift
				break
				;;
		esac
		shift
	done

	[ $# -eq 0 ] || fatal "[PRE-FLIGHT]" "unrecognized argument '$1'"
}

#------------------------
#--- LIQO AGENT SETUP ---
#------------------------

function get_agent_releases() {
	# The maximum number of retrieved tags is 100, but this should not raise concerns for a while
	local RELEASES_URL="https://api.github.com/repos/${LIQOAGENT_REPO}/releases?page=1&per_page=100"
	download "${RELEASES_URL}" | grep -Po '"tag_name": "\K.*?(?=")' || echo ""
}

function setup_agent_version() {
	# Check if LIQO_REPO has been set
	LIQOAGENT_REPO="${LIQOAGENT_REPO:-${LIQOAGENT_REPO_DEFAULT}}"
	# Get tags of available LiqoAgent releases (if any).
	local AGENT_RELEASES
	AGENT_RELEASES=$(get_agent_releases)
	if [[ -z "${AGENT_RELEASES}" ]]; then
		warn "[PRE-FLIGHT] [INSTALL]" "No releases are found on LiqoAgent repositories"
		return 0
	fi
	DOWNLOAD_VERSION=$(printf "%s" "${AGENT_RELEASES}" | head --lines=1)
	# Identify LiqoAgent version to be downloaded. If user selected an unavailable version
	# or did not express a preference, the latest release is chosen by default.
	local FOUND
	if [[ "${LIQOAGENT_VERSION:-}" == "" ]]; then
		info "[PRE-FLIGHT] [INSTALL]" "latest version is selected (${DOWNLOAD_VERSION})"
	else
		info "[PRE-FLIGHT] [INSTALL]" "Checking if requested version exists..."
		FOUND=$(printf "%s" "${AGENT_RELEASES}" | grep -P --silent "^${LIQOAGENT_VERSION}$" || echo "no")
		if [[ "${FOUND}" == "no" ]]; then
			warn "[PRE-FLIGHT] [INSTALL]" "${LIQOAGENT_VERSION} does not exist. Switching to 'latest'"
		else
			info "[PRE-FLIGHT] [INSTALL]" "OK!"
			DOWNLOAD_VERSION="${LIQOAGENT_VERSION}"
		fi
	fi
}

function download_agent() {
	# Download both binary and repo code to access external resources.
	setup_tmpdir
	command_exists tar || fatal "[PRE-FLIGHT] [INSTALL]" "'tar' is not available"
	ASSET_NAME="liqo-agent"
	RELEASE_CODE_URL="https://github.com/${LIQOAGENT_REPO}/archive/${DOWNLOAD_VERSION}.tar.gz"
	RELEASE_ASSET_URL="https://github.com/${LIQOAGENT_REPO}/releases/download/${DOWNLOAD_VERSION}/${ASSET_NAME:-liqo-agent}.tar.gz"
	download "${RELEASE_CODE_URL}" | tar xpzf - --directory="${AGENT_REPO_DOWNLOAD_DIR}" --strip 1 2>/dev/null ||
		fatal "[PRE-FLIGHT] [INSTALL]" "Something went wrong while extracting the LiqoAgent archive"
	download "${RELEASE_ASSET_URL}" | tar xpzf - --directory="${AGENT_BIN_DOWNLOAD_DIR}" 2>/dev/null ||
		fatal "[PRE-FLIGHT] [INSTALL]" "Something went wrong while extracting the LiqoAgent executable"
}

function setup_agent_environment() {
	[[ -z ${HOME:-} ]] && HOME=~
	# Default directory for XDG_CONFIG_HOME.
	AGENT_XDG_CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config/}"
	# Default directory for XDG_DATA_HOME.
	AGENT_XDG_DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}"

	# Directory containing the Agent binary.
	AGENT_BIN_INSTALL_DIR="${HOME}/.local/bin"
	# Liqo Agent root directory containing all related resources.
	AGENT_DATA_INSTALL_DIR="${AGENT_XDG_DATA_DIR}/liqo"
	# Name of the Liqo Agent config file.
	AGENT_CONFIG_FILE_NAME="agent_conf.yaml"
	# Filepath of the Liqo Agent config file.
	AGENT_CONF_FILE_PATH="${AGENT_DATA_INSTALL_DIR}/${AGENT_CONFIG_FILE_NAME}"
	# Liqo subdirectory containing the notifications icons.
	AGENT_ICONS_DIR="${AGENT_DATA_INSTALL_DIR}/icons"
	# Directory storing the '.desktop' file.
	AGENT_APP_DIR="${AGENT_XDG_DATA_DIR}/applications"
	# Directory storing the scalable icon for the desktop application.
	AGENT_THEME_DIR="${AGENT_XDG_DATA_DIR}/icons/hicolor/scalable/apps"
	# Directory storing the '.desktop' file to enable the application autostart.
	AGENT_AUTOSTART_DIR="${AGENT_XDG_CONFIG_DIR}/autostart"

	if [[ "${1:-}" == "--create" ]]; then
		mkdir --parent "${AGENT_XDG_CONFIG_DIR}" "${AGENT_XDG_DATA_DIR}" \
			"${AGENT_BIN_INSTALL_DIR}" "${AGENT_ICONS_DIR}" "${AGENT_APP_DIR}" \
			"${AGENT_THEME_DIR}" "${AGENT_AUTOSTART_DIR}"
	fi
}

#-----------------------
#--- AGENT INSTALLER ---
#-----------------------

function write_agent_config_file() {
	# If there are configuration parameters whose value differs from default, write them down to the agent
	# configuration file, creating or truncating the file if already present.
	# Currently the only considered information is the kubeconfig file path (KUBECONFIG env var).
	if [[ "${KUBECONFIG:-}" != "${HOME}/.kube/config" ]]; then
		echo "kubeconfig: ${KUBECONFIG}" >"${AGENT_CONF_FILE_PATH}"
	fi
}

function install_agent() {
	info "[PRE-FLIGHT] [INSTALL]" "LiqoAgent installation"
	# Currently Liqo Agent is released only for GNU-Linux desktop environments.
	# No direct check on desktop environment scope for the release is performed.
	setup_downloader
	setup_agent_version
	if [[ -z "${DOWNLOAD_VERSION:-}" ]]; then
		warn "[PRE-FLIGHT] [INSTALL]" "No Liqo Agent binary found! Skipping Agent installation"
		return 0
	fi
	info "[PRE-FLIGHT] [INSTALL]" "Downloading LiqoAgent (version: ${DOWNLOAD_VERSION})"
	download_agent
	info "[INSTALL] [1/3]" "Getting things ready..."
	setup_agent_environment --create
	info "[INSTALL] [2/3]" "Installing LiqoAgent app..."
	# moving binary
	mv -f "${AGENT_BIN_DOWNLOAD_DIR}/liqo-agent" "${AGENT_BIN_INSTALL_DIR}"
	# moving notifications icons
	mv -f "${AGENT_ASSETS_DIR}"/icons/desktop/* "${AGENT_ICONS_DIR}" ||
		fatal "[AGENT] [INSTALL]" "Something went wrong while copying files"
	# INSTALL AGENT AS A DESKTOP APPLICATION
	# a) Inject binary path into '.desktop' file.
	echo Exec='"'"${AGENT_BIN_INSTALL_DIR}/liqo-agent"'"' >> "${AGENT_INSTALL_LINUX_DIR}/io.liqo.Agent.desktop"
	# The x permission is required to let the system trust the application to autostart.
	chmod +x "${AGENT_INSTALL_LINUX_DIR}/io.liqo.Agent.desktop"
	# b) The '.desktop' file is installed in one of the XDG_DATA_* directories to let the
	# system recognize Liqo Agent as a desktop application.
	cp -f "${AGENT_INSTALL_LINUX_DIR}/io.liqo.Agent.desktop" "${AGENT_APP_DIR}"
	# c) The '.desktop' file is installed in one of the XDG_CONFIG_* directories to enable autostart.
	# Having the file in both directories allows an easier management of a "don't start at boot" option.
	mv -f "${AGENT_INSTALL_LINUX_DIR}/io.liqo.Agent.desktop" "${AGENT_AUTOSTART_DIR}"
	# d) The Liqo Agent desktop icon is exported in 'scalable' format for the default theme to one of the
	# $XDG_DATA_*/icons/hicolor/scalable/apps directories.
	mv -f "${AGENT_INSTALL_LINUX_DIR}/io.liqo.Agent.svg" "${AGENT_THEME_DIR}"
	# e) In order to automatically trust the application, the '.desktop' file copies' metadata
	# are trusted using gio after they are moved in their respective location.
	if command_exists gio; then
		gio set "${AGENT_APP_DIR}/io.liqo.Agent.desktop" "metadata::trusted" yes
		gio set "${AGENT_AUTOSTART_DIR}/io.liqo.Agent.desktop" "metadata::trusted" yes
	fi
	# f) If there are specific parameters needed by the Agent, these are written to a config file.
	info "[INSTALL] [3/3]" "Setting configuration up..."
	write_agent_config_file
	info "[INSTALL]" "Done!"
	command_exists gtk-launch && gtk-launch io.liqo.Agent.desktop
}

#-------------------------
#--- AGENT UNINSTALLER ---
#-------------------------

function uninstall_agent() {
	setup_agent_environment
	info "[AGENT] [UNINSTALL]" "Uninstalling Liqo Agent..."
	# Uninstalling main components.
	rm -f "${AGENT_BIN_INSTALL_DIR}/liqo-agent"
	rm -rf "${AGENT_DATA_INSTALL_DIR}"
	# Uninstalling desktop application files.
	rm -f "${AGENT_APP_DIR}/io.liqo.Agent.desktop"
	rm -f "${AGENT_AUTOSTART_DIR}/io.liqo.Agent.desktop"
	rm -f "${AGENT_THEME_DIR}/io.liqo.Agent.svg"
	info "[AGENT] [UNINSTALL]" "Liqo Agent was correctly uninstalled"
}

#---------------------------

function main() {
	# Set graphic environment
	setup_colors
	print_logo

	# Check requirements
	setup_arch_and_os
	parse_arguments "$@"

	if [[ ${INSTALL_LIQO_AGENT} == true ]]; then
		install_agent
	else
		uninstall_agent
	fi
}

# This check prevents the script from being executed when sourced,
# hence enabling the possibility to perform unit testing
if ! (return 0 2>/dev/null); then
	main "$@"
	exit ${EXIT_SUCCESS}
fi
