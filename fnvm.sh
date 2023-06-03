# faster nvm use
fnvm_use() {
	version_dir=$(nvm_version_path "$1" 2> /dev/null)
	if [ ! -z "$version_dir" ] && [ -e "$version_dir" ]; then
		[ "$FNVM_VER" = "$1" ] && return
		export PATH=$(nvm_change_path "${PATH}" "/bin" "${version_dir}")
		export NVM_BIN="${version_dir}/bin"
		export NVM_INC="${version_dir}/include/node"
		export FNVM_VER="$1"
	else
		echo "ERROR: path '$version_dir' is not exist, failed to load nodejs. please check your ~/.nvmrc.cached"
		echo "Tip: To init .nvmrc.cached follow this step"
		echo "  nvm install node # Choose version you want"
		echo "  nvm use node"
		echo "  node --version > ~/.nvmrc.cached"
		echo "  export FNVM_VER=\$(cat ~/.nvmrc.cached)"
	fi
}

# load .nvmrc or ~/.nvmrc.default
fnvm_apply() {
	# find .nvmrc file on cwd
	cpd_nvmrc=$(nvm_find_nvmrc)
	if [ ! -z "$cpd_nvmrc" ]; then
		# found nvmrc, and match with last nvmrc file
		[ "$cpd_nvmrc" = "$FNVM_NVMRC" ] && return

		# check is installed
		content="$(cat "$cpd_nvmrc")"
		version=$(nvm_match_version "$content")
		if [ "$version" = "N/A" ]; then
			# not found, install it
			echo "version '$content' not found. install it"
			nvm install "$content"
		else
			# found it, use with faster method
			fnvm_use $version
			echo "Found '$cpd_nvmrc' with version $version"
		fi
		export FNVM_NVMRC=$cpd_nvmrc
		return
	fi

	# load default version
	[ "$FNVM_NVMRC" = "$FNVM_NVMRC_DEFAULT" ] && return
	[ ! -z "$FNVM_NVMRC" ] && echo "Reverting to ~/.nvmrc.default"
	export FNVM_NVMRC="$FNVM_NVMRC_DEFAULT"
	fnvm_use "$(cat $FNVM_NVMRC_DEFAULT)"
}

# cd wraping
fnvm_cd() {
	\cd $@ && fnvm_update
}

# update fnvm
fnvm_update() {
	git -C $NVM_DIR/fnvm pull
	fnvm_uninit

	# load installer
	if [ "$(basename "$(pwd)")" = "fnvm" ] && [ -e "./installer.sh" ]; then
		source ./installer.sh
	else
		source $nvmdir/fnvm/installer.sh
	fi

	[ -e "$HOME/.zshrc" ] && fnvm_update_rcfile "$HOME/.zshrc"
	[ -e "$HOME/.bashrc" ] && fnvm_update_rcfile "$HOME/.bashrc"
	
	source $nvmdir/fnvm/fnvm.sh
	fnvm_init
}

# unload fnvm
fnvm_uninit() {
	which nvm 2>/dev/null 1>/dev/null && nvm unload

	if [ "$FNVM_DISABLE_CD" != "yes" ]; then
		if [ -n "${ZSH_VERSION-}" ]; then
			# remove zsh hook
			add-zsh-hook -d chpwd fnvm_update
		else
			# remove bash hook
			unalias cd 2>/dev/null 1>/dev/null
		fi
	fi

	unset FNVM_NVMRC_DEFAULT
	unset FNVM_NVMRC
}

# load fnvm
fnvm_init() {
	export NVM_DIR="$HOME/.nvm"
	export FNVM_NVMRC_DEFAULT="$HOME/.nvmrc.default"
	shell_name=$(basename $(echo $0))

	source "$NVM_DIR/nvm.sh" --no-use
	[ "$shell_name" = "bash" ] && source "$NVM_DIR/bash_completion"

	if [ "$FNVM_DISABLE_CD" != "yes" ]; then
		if [ -n "${ZSH_VERSION-}" ]; then
			# this terminal is zsh, using add-zsh-hook to hooking cd
			autoload -U add-zsh-hook
			add-zsh-hook chpwd fnvm_apply
		else
			# bash or something else
			alias cd=fnvm_cd
		fi
	fi
	fnvm_apply
}