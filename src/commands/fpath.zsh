###
# Output usage information
###
function _zulu_fpath_usage() {
  echo $(_zulu_color yellow "Usage:")
  echo "  zulu fpath <context> <dir>"
  echo
  echo $(_zulu_color yellow "Context:")
  echo "  add <dir>   Add a directory to \$fpath"
  echo "  reset       Replace the current session \$fpath with the stored dirs"
  echo "  rm <dir>    Remove a directory from \$fpath"
}

###
# Check the existence of a directory when passed as an argument,
# and convert relative paths to absolute
###
function _zulu_fpath_parse() {
  local dir="$1" check_existing="$2"

  if [[ -d "$PWD/$dir" ]]; then
    # If the directory exists in the current working directory
    # convert the relative path to absolute
    echo "$PWD/$dir"
  elif [[ -d "$dir" ]]; then
    # If the directory exists as an absolute path, we can use it directly
    echo "$dir"
  elif [[ "$check_existing" != "false" ]]; then
    # The directory could not be found
    echo $dir
    return 1
  fi
}

###
# Add a directory to $fpath
###
function _zulu_fpath_add() {
  local dir p
  local -a items paths; paths=($(cat $pathfile))

  # Check that each of the passed directories exist, and convert relative
  # paths to absolute
  for dir in "$@"; do
    dir=$(_zulu_fpath_parse "$dir")

    # If parsing returned with an error, output the error and return
    if [[ $? -eq 0 ]]; then
      # Add the directory to the array of items
      items+="$dir"

      echo "$(_zulu_color green '✔') $dir added to \$fpath"
    else
      echo "$(_zulu_color red '✘') $dir cannot be found"
    fi

  done

  # Loop through each of the existing paths and add those to the array as well
  for p in "$paths[@]"; do
    items+="$p"
  done

  # Store the new paths in the pathfile, and override $fpath
  _zulu_fpath_store
  _zulu_fpath_reset
}

###
# Remove a directory from $fpath
###
function _zulu_fpath_rm() {
  local dir p
  local -a items paths; paths=($(cat $pathfile))

  # Check that each of the passed directories exist, and convert relative
  # paths to absolute
  for dir in "$@"; do
    dir=$(_zulu_fpath_parse "$dir" "false")

    # If parsing returned with an error, output the error and return
    if [[ ! $? -eq 0 ]]; then
      echo $dir
      return 1
    fi

    # Loop through each of the paths, and if they are *not* an exact match,
    # we want to keep them
    for p in "$paths[@]"; do
      if [[ "$p" != "$dir" ]]; then
        items+="$p"
      fi
    done

    echo "$(_zulu_color green '✔') $dir removed from \$fpath"
  done

  # Store the new paths in the pathfile, and override $fpath
  _zulu_fpath_store
  _zulu_fpath_reset
}

###
# Store an array of paths in the pathfile
###
function _zulu_fpath_store() {
  local separator out

  # Separate the array by newlines, and print the contents to the pathfile
  separator=$'\n'
  local oldIFS=$IFS
  IFS="$separator"; out="${items[*]/#/${separator}}"
  echo ${out:${#separator}} >! $pathfile
  IFS=$oldIFS
  unset oldIFS
}

###
# Override the $fpath variable with the current contents of the pathfile
###
function _zulu_fpath_reset() {
  local separator out
  local -a paths; paths=($(cat $pathfile))

  typeset -gUa fpath; fpath=()
  for p in "${paths[@]}"; do
    fpath+="$p"
  done
}

###
# Zulu command to handle path manipulation
###
function _zulu_fpath() {
  local ctx base pathfile

  # Parse options
  zparseopts -D h=help -help=help

  # Output help and return if requested
  if [[ -n $help ]]; then
    _zulu_fpath_usage
    return
  fi

  # Set up some variables
  base=${ZULU_DIR:-"${ZDOTDIR:-$HOME}/.zulu"}
  config=${ZULU_CONFIG_DIR:-"${ZDOTDIR:-$HOME}/.config/zulu"}
  pathfile="${config}/fpath"

  # If no context is passed, output the contents of the pathfile
  if [[ "$1" = "" ]]; then
    cat "$pathfile"
    return
  fi

  # Get the context
  ctx="$1"

  # Call the relevant function
  _zulu_fpath_${ctx} "${(@)@:2}"
}
