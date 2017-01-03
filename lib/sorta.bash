[[ -n ${_sorta:-} ]] && return
readonly _sorta=loaded

_options() {
  case $1 in
    '@')
      printf 'a'
      ;;
    '%')
      printf 'A'
      ;;
  esac
}

assign() {
  local _ref=$1
  local _value=$2
  local _name

  _name=${_value%%=*}
  _name=${_name##* }
  printf '%s' "${_value/$_name/$_ref}"
}

pass() { declare -p "$1" ;}

passed() {
  local -n _parameters=$1; shift
  local -a _arguments=( "$@" )
  local -a _results
  local IFS
  local _argument=''
  local _declaration
  local _i
  local _parameter
  local _type

  for _i in "${!_parameters[@]}"; do
    _parameter=${_parameters[$_i]}
    [[ $_parameter == *=* ]] && _argument=${_parameter#*=}
    _parameter=${_parameter%%=*}
    [[ ${_arguments[$_i]+x} == 'x' ]] && _argument=${_arguments[$_i]}
    _type=${_parameter:0:1}
    case $_type in
      '@' | '%' )
        _parameter=${_parameter:1}
        if [[ $_argument == '('* ]]; then
          _declaration=$(printf 'declare -%s %s=%s%s%s' "$(_options "$_type")" "$_parameter" \' "$_argument" \')
          eval "$_declaration"
          _declaration=$(declare -p "$_parameter")
        else
          _declaration=$(declare -p "$_argument")
          _declaration=${_declaration/$_argument/$_parameter}
        fi
        _results+=( "$_declaration" )
        ;;
      '&' )
        _parameter=${_parameter:1}
        _results+=( "$(printf 'declare -n %s="%s"' "$_parameter" "$_argument")" )
        ;;
      * )
        if declare -p "$_argument" >/dev/null 2>&1; then
          _declaration=$(declare -p "$_argument")
          _declaration=${_declaration/$_argument/$_parameter}
        else
          { [[ $_argument == *[* ]] && declare -p "${_argument%[*}" >/dev/null 2>&1 ;} && {
            [[ ${!_argument+x} == 'x' ]] || return
            _argument=${!_argument}
          }
          # shellcheck disable=SC2030
          _declaration=$(declare -p _argument)
          _declaration=${_declaration/_argument/$_parameter}
        fi
        _results+=( "$_declaration" )
        ;;
    esac
  done
  IFS=';'
  printf '%s\n' "${_results[*]}"
}