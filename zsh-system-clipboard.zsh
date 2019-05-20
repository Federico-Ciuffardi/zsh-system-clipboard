#!/usr/bin/env zsh

##
# zsh-system-clipboard
#
# @author
#	Kutsan Kaplan <me@kutsankaplan.com>
#	Doron Behar <doron.behar@gmail.com>
# @license GPL-3.0
# @version v0.7.0
##

function _zsh_system_clipboard_error() {
	echo -e "\n\n  \033[41;37m ERROR \033[0m \033[01mzsh-system-clipboard:\033[0m $@\n" >&2
}

function _zsh_system_clipboard_suggest_to_install() {
	_zsh_system_clipboard_error "Could not find any available clipboard manager. Make sure you have \033[01m${@}\033[0m installed."
	return 1
}

case "$OSTYPE" {
	darwin*)
		if ((hash pbcopy && hash pbpaste) 2>/dev/null) {
			alias _zsh_system_clipboard_set='pbcopy'
			alias _zsh_system_clipboard_get='pbpaste'
		} else {
			_zsh_system_clipboard_suggest_to_install 'pbcopy, pbpaste'
		}
		;;
	linux-android*)
		if ((hash termux-clipboard-set && hash termux-clipboard-get) 2>/dev/null) {
			alias _zsh_system_clipboard_set='termux-clipboard-set'
			alias _zsh_system_clipboard_get='termux-clipboard-get'
		} else {
			_zsh_system_clipboard_suggest_to_install 'Termux:API (from Play Store), termux-api (from apt package)'
		}
		;;
	linux*|freebsd*)
		if (hash xclip 2>/dev/null) {
			local clipboard_selection
			case $ZSH_SYSTEM_CLIPBOARD_SELECTION {
				PRIMARY)
					clipboard_selection='PRIMARY'
					;;
				CLIPBOARD)
					clipboard_selection='CLIPBOARD'
					;;
				*)
					if [[ $ZSH_SYSTEM_CLIPBOARD_SELECTION != '' ]] {
						_zsh_system_clipboard_error "\033[01m$ZSH_SYSTEM_CLIPBOARD_SELECTION\033[0m is not a valid value for \$ZSH_SYSTEM_CLIPBOARD_SELECTION. Please assign either 'PRIMARY' or 'CLIPBOARD'."
					} else {
						clipboard_selection='CLIPBOARD'
					}
					;;
			}
			alias _zsh_system_clipboard_set="xclip -sel $clipboard_selection -in"
			alias _zsh_system_clipboard_get="xclip -sel $clipboard_selection -out"
		} elif (hash xsel 2>/dev/null) {
			local clipboard_selection
			case $ZSH_SYSTEM_CLIPBOARD_SELECTION {
				PRIMARY)
					clipboard_selection='-p'
					;;
				CLIPBOARD)
					clipboard_selection='-b'
					;;
				*)
					if [[ $ZSH_SYSTEM_CLIPBOARD_SELECTION != '' ]] {
						_zsh_system_clipboard_error "\033[01m$ZSH_SYSTEM_CLIPBOARD_SELECTION\033[0m is not a valid value for \$ZSH_SYSTEM_CLIPBOARD_SELECTION. Please assign either 'PRIMARY' or 'CLIPBOARD'."
					} else {
						clipboard_selection='-b'
					}
					;;
			}
			alias _zsh_system_clipboard_set="xsel $clipboard_selection -i"
			alias _zsh_system_clipboard_get="xsel $clipboard_selection -o"
		} else {
			_zsh_system_clipboard_suggest_to_install 'xclip or xsel'
		}
		;;
	*)
		_zsh_system_clipboard_error 'Unsupported system.'
		return 1
		;;
}
unfunction _zsh_system_clipboard_error
unfunction _zsh_system_clipboard_suggest_to_install

case "$OSTYPE" {
	linux*|freebsd*)
		if [[ "$ZSH_SYSTEM_CLIPBOARD_TMUX_SUPPORT" != '' ]] && (hash tmux &>/dev/null && [[ "$TMUX" != '' ]]); then
			if [[ ! -z "$DISPLAY" ]]; then
				zsh-system-clipboard-set(){
					# Based on https://unix.stackexchange.com/a/28519/135796
					tee >(tmux set-buffer -- "$(cat -)") | _zsh_system_clipboard_set
				}
				zsh-system-clipboard-get(){
					_zsh_system_clipboard_get
				}
			else
				zsh-system-clipboard-set(){
					tmux load-buffer -
				}
				zsh-system-clipboard-get(){
					tmux show-buffer
				}
			fi
		else
			if [[ ! -z "$DISPLAY" ]]; then
				zsh-system-clipboard-set(){
					_zsh_system_clipboard_set
				}
				zsh-system-clipboard-get(){
					_zsh_system_clipboard_get
				}
			else
				return 1
			fi
		fi
		;;
	*)
		if [[ "$ZSH_SYSTEM_CLIPBOARD_TMUX_SUPPORT" != '' ]] && (hash tmux &>/dev/null && [[ "$TMUX" != '' ]]); then
			zsh-system-clipboard-set(){
				# Based on https://unix.stackexchange.com/a/28519/135796
				tee >(tmux set-buffer -- "$(cat -)") | _zsh_system_clipboard_set
			}
		else
			zsh-system-clipboard-set(){
				_zsh_system_clipboard_set
			}
		fi
		zsh-system-clipboard-get(){
			_zsh_system_clipboard_get
		}
		;;
}

function zsh-system-clipboard-vicmd-vi-yank() {
	zle vi-yank
	if [[ "${KEYS}" == "y" && "${KEYMAP}" == 'viopp' ]]; then # A new line should be added to the end
		printf '%s\n' "$CUTBUFFER" | zsh-system-clipboard-set
	else
		printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set
	fi
}
zle -N zsh-system-clipboard-vicmd-vi-yank

function zsh-system-clipboard-vicmd-vi-yank-whole-line() {
	zle vi-yank-whole-line
	printf '%s\n' "$CUTBUFFER" | zsh-system-clipboard-set
}
zle -N zsh-system-clipboard-vicmd-vi-yank-whole-line

# Wrapper function for common calculations of both put-after and put-before
function zsh-system-clipboard-vicmd-vi-put() {
	local CLIPBOARD
	local mode="$1"
	# TODO: put-after of a not-whole-line, when cursor is on empty line, puts selcetion at the start of the line afterwards
	CLIPBOARD="$(zsh-system-clipboard-get; printf '%s' x)"
	CLIPBOARD="${CLIPBOARD%x}"
	# Checks if the last character is a new line
	if [[ "${CLIPBOARD[${#CLIPBOARD}]}" == $'\n' ]]; then
		# if so, we need to check if we have more lines below the cursor.
		# The following variable gets the contents of the whole RBUFFER up
		# until the next new-line.
		local RBUFFER_UNTIL_LINE_END="${RBUFFER%%$'\n'*}"
		# therefor, this comparison tells us if we have more new lines or not
		if [[ "${RBUFFER_UNTIL_LINE_END}" == "${RBUFFER}" && "$mode" == "after" ]]; then
			# we don't have any more newlines in RBUFFER.
			# Therefor, we add a new line at the beginning of our original
			# clipboard so it will append the whole BUFFER eventually
			CLIPBOARD=$'\n'"${CLIPBOARD%%$'\n'}"
		fi
		# If we are pasting a whole-line selection we need to put the cursor at
		# the correct position, according to our mode of input
		if [[ "$mode" == "after" ]]; then
			CURSOR="$(( ${CURSOR} + ${#RBUFFER_UNTIL_LINE_END} ))"
		else
			# We use the single % for the smallest match possible
			local LBUFFER_UNTIL_LINE_END="${LBUFFER%$'\n'*}"
			echo LBUFFER_UNTIL_LINE_END is "${(q)LBUFFER_UNTIL_LINE_END}" >> ~/zdbg
			CURSOR="$(( ${#LBUFFER_UNTIL_LINE_END} + 1 ))"
		fi
	fi
	if [[ "$mode" == "after" ]]; then
		BUFFER="${BUFFER:0:$(( ${CURSOR} + 1 ))}${CLIPBOARD}${BUFFER:$(( ${CURSOR} + 1 ))}"
		CURSOR=$(( $#LBUFFER + $#CLIPBOARD ))
	else
		BUFFER="${BUFFER:0:$(( ${CURSOR} ))}${CLIPBOARD}${BUFFER:$(( ${CURSOR} ))}"
		CURSOR=$(( $#LBUFFER + $#CLIPBOARD - 1 ))
	fi
}

function zsh-system-clipboard-vicmd-vi-put-after() {
	zsh-system-clipboard-vicmd-vi-put after
}
zle -N zsh-system-clipboard-vicmd-vi-put-after

function zsh-system-clipboard-vicmd-vi-put-before() {
	zsh-system-clipboard-vicmd-vi-put before
}
zle -N zsh-system-clipboard-vicmd-vi-put-before

function zsh-system-clipboard-vicmd-vi-delete() {
	zle vi-delete
	if [[ "${KEYS}" == "d" ]]; then # A new line should be added to the end
		printf '%s\n' "$CUTBUFFER" | zsh-system-clipboard-set
	else
		printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set
	fi
}
zle -N zsh-system-clipboard-vicmd-vi-delete

function zsh-system-clipboard-vicmd-vi-delete-char() {
	zle vi-delete-char
	printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set
}
zle -N zsh-system-clipboard-vicmd-vi-delete-char

function zsh-system-clipboard-vicmd-vi-change-eol() {
	zle vi-change-eol
	printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set
}
zle -N zsh-system-clipboard-vicmd-vi-change-eol

function zsh-system-clipboard-vicmd-vi-kill-eol() {
	zle vi-kill-eol
	printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set
}
zle -N zsh-system-clipboard-vicmd-vi-kill-eol

function zsh-system-clipboard-vicmd-vi-change-whole-line() {
	zle vi-change-whole-line
	printf '%s\n' "$CUTBUFFER" | zsh-system-clipboard-set
}
zle -N zsh-system-clipboard-vicmd-vi-change-whole-line

function zsh-system-clipboard-vicmd-vi-change() {
	zle vi-change
	printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set
}
zle -N zsh-system-clipboard-vicmd-vi-change

function zsh-system-clipboard-vicmd-vi-substitue() {
	zle vi-substitue
	printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set
}
zle -N zsh-system-clipboard-vicmd-vi-substitue

function zsh-system-clipboard-vicmd-vi-delete-char() {
	zle vi-delete-char
	printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set
}
zle -N zsh-system-clipboard-vicmd-vi-delete-char

function zsh-system-clipboard-vicmd-vi-backward-delete-char() {
	zle vi-backward-delete-char
	printf '%s' "$CUTBUFFER" | zsh-system-clipboard-set
}
zle -N zsh-system-clipboard-vicmd-vi-backward-delete-char

# Bind keys to widgets.
function () {
	local binded_keys i parts key cmd keymap
	for keymap in vicmd visual emacs; do
		binded_keys=(${(f)"$(bindkey -M $keymap)"})
		for (( i = 1; i < ${#binded_keys[@]}; ++i )); do
			parts=("${(z)binded_keys[$i]}")
			key="${parts[1]}"
			cmd="${parts[2]}"
			if (( $+functions[zsh-system-clipboard-$keymap-$cmd] )); then
				eval bindkey -M $keymap $key zsh-system-clipboard-$keymap-$cmd
			fi
		done
	done
}
