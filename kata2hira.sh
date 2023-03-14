#!/bin/sh

######################################################################
#
# KATA2HIRA - Convert from Katakana into Hiragana in the Selected Fields
#
# USAGE: kata2hira [+<n>h] <f1> <f2> ... <file>
#        kata2hira -d <f1> <f2> ... <string>
#
#        <fn> .... Time field number you want to convert
#        <file> .. Text file which contains some time field to convert
#        <string>  It will be explained in -d option
#        -d ...... Direct Mode :
#                  It make this command regard the last argument (<string>)
#                  as a field formatted string instead of <file>
#        +<n>h ... Regards the top <n> lines as comment and Print without
#                  converting
#
# Designed originally by Nobuaki Tounaka
# Written by Shell-Shoccar Japan (@shellshoccarjpn) on 2020-05-06
#
# This is a public-domain software (CC0). It means that all of the
# people can use this for any purposes with no restrictions at all.
# By the way, We are fed up with the side effects which are brought
# about by the major licenses.
#
# The latest version is distributed at the following page.
# https://github.com/ShellShoccar-jpn/misc-tools
#
######################################################################


######################################################################
# Initial Configuration
######################################################################

# === Initialize shell environment ===================================
set -u
umask 0022
export LC_ALL=C
export PATH="$(command -p getconf PATH 2>/dev/null)${PATH+:}${PATH-}"
case $PATH in :*) PATH=${PATH#?};; esac
export UNIX_STD=2003  # to make HP-UX conform to POSIX

# === Define the functions for printing usage and error message ======
print_usage_and_exit () {
  cat <<-USAGE 1>&2
	Usage   : ${0##*/} [+<n>h] <f1> <f2> ... <file>
	          ${0##*/} -d <f1> <f2> ... <string>
	Options : -d ...... Direct Mode :
	                    It make this command regard the last argument (<string>)
	                    as a field formatted string instead of <file>
	          +<n>h ... Regards the top <n> lines as comment and Print without
	                    converting
	Version : 2020-05-06 22:42:19 JST
	          (POSIX.1 Bourne Shell/POSIX.1 commands/UTF-8)
	USAGE
  exit 1
}
error_exit() {
  ${2+:} false && echo "${0##*/}: $2" 1>&2
  exit $1
}


######################################################################
# Parse Arguments
######################################################################

# === Get the options and the filepath ===============================
# --- initialize option parameters -----------------------------------
directmode=0
directstr=''
file=''
fldnums=''
all_fields=0
use_stdin=0
opt_part=1
opth=0
#
# --- get them -------------------------------------------------------
case "$#${1:-}" in
  1-h|1--help|1--version) print_usage_and_exit;;
esac
case $# in [!0]*)
  i=0
  for arg in ${1+"$@"}; do
    i=$((i+1))
    fldnum=''
    # direct mode processing
    if   [ $opt_part -ne 0 ] && [ "_$arg" = '_-d'        ]; then
      directmode=1
      continue
    elif [ $opt_part -ne 0 ] && [ "_$arg" != "_${arg#+}" ]; then
      s=$(printf '%s\n' "$arg" | sed 's/^+\([0-9]*\)h$/\1/')
      case "$s" in "$arg") print_usage_and_exit;; esac
      case "$s" in     '') opth=1; continue    ;; esac
      opth=$(expr $s + 0)
      continue
    fi
    opt_part=0
    case "$i$directmode" in "${#}1") directstr=$arg; break;; esac
    # separate arg to arg1, arg2
    arg1=${arg%%/*}
    arg2=${arg##*/}
    if [ "_${arg1}/${arg2}" = "_$arg" ] && [ -n "$arg1" ] && [ -n "$arg2" ]
    then
      :
    else
      arg1=$arg
      arg2=''
    fi
    # check both
    j=0
    for s in $arg1 $arg2; do
      if printf '%s\n' "$s" | grep -q '^[0-9]\{1,\}$'; then
        j=$((j+1))
        case "$s" in 0) all_fields=1;; esac
      elif printf '%s\n' "$s" | grep -Eq '^(NF|NF-[0-9]+)$'; then
        j=$((j+1))
      fi
    done
    if [ $j -eq 2 ] || ([ $j -eq 1 ] && [ -z "$arg2" ]); then
      fldnums="$fldnums $arg"
      continue
    fi
    # perhaps, this argument is a filename
    case $# in $i) file=$arg; continue;; esac
    # otherwise, it is a invalid argument
    print_usage_and_exit
  done
  ;;
esac

# === Validate the arguments =========================================
# (if you want to regard no fldnums as all, set all_fields=1 instead of exit)
case "$fldnums" in '') all_fields=1;; esac
if [ $directmode -ne 0 ]; then
  case "$directstr" in '') print_usage_and_exit;; esac
  file=''
elif [ "_$file" = '_'                ] ||
     [ "_$file" = '_-'               ] ||
     [ "_$file" = '_/dev/stdin'      ] ||
     [ "_$file" = '_/dev/fd/0'       ] ||
     [ "_$file" = '_/proc/self/fd/0' ]  ; then
  file=''
elif [ -f "$file"                    ] ||
     [ -c "$file"                    ] ||
     [ -p "$file"                    ]  ; then
  [ -r "$file" ] || error_exit 1 'Cannot open the file: '"$file"
else
  print_usage_and_exit
fi
case "$file" in ''|-|/*|./*|../*) :;; *) file="./$file";; esac


######################################################################
# Prepare for the Main Routine
######################################################################

# === Generate the partial code for AWK ==============================
case $all_fields in
  0) awkc0=$(echo "$fldnums"                           |
             sed 's/^0\{1,\}\([0-9]\)/\1/'             |
             sed 's/\([^0-9]\)0\{1,\}\([0-9]\)/\1\2/g' |
             tr ' ' '\n'                               |
             awk                                       '
               /^NF-[0-9]+\/NF-[0-9]+$/ {
                 nfofs1 = substr($0,4,index($0,"/")-4) + 0;
                 nfofs2 = substr($0,index($0,"/")+4) + 0;
                 if (nfofs1 > nfofs2) {
                   i = nfofs1;
                   nfofs1 = nfofs2;
                   nfofs2 = i;
                 }
                 for (i=nfofs1; i<=nfofs2; i++) {
                   print "0 NF-" i;
                 }
               }
               /^NF\/NF-[0-9]+$/ {
                 nfofs2 = substr($0,index($0,"/")+4);
                 print "0 NF";
                 for (i=1; i<=nfofs2; i++) {
                   print "0 NF-" i;
                 }
               }
               /^NF-[0-9]+\/NF$/ {
                 nfofs2 = substr($0,4,index($0,"/")-4) + 0;
                 print "0 NF";
                 for (i=1; i<=nfofs2; i++) {
                   print "0 NF-" i;
                 }
               }
               /^[0-9]+\/NF-[0-9]+$/ {
                 printf("0 %s NF-%s\n",
                        substr($0,1,index($0,"/")-1),
                        substr($0,index($0,"/")+4)   );
               }
               /^NF-[0-9]+\/[0-9]+$/ {
                 printf("0 %s NF-%s\n",
                        substr($0,index($0,"/")+1),
                        substr($0,4,index($0,"/")-4));
               }
               /^[0-9]+\/[0-9]+$/ {
                 pos = index($0, "/");
                 a = substr($0, 1, pos-1)+0;
                 b = substr($0, pos+1)+0;
                 if (a > b) {
                   swp = a;
                   a = b;
                   b = swp;
                 }
                 for (i=a; i<=b; i++) {
                   print 1, i;
                 }
               }
               /^[0-9]+\/NF$/ {
                 print 1, substr($0, 1, length($0)-3), "NF";
               }
               /^NF\/[0-9]+$/ {
                 print 1, substr($0, index($0,"/")+1), "NF";
               }
               /^[0-9]+$/ {
                 print 1, $0;
               }
               /^NF-[0-9]+$/ {
                 print 0, $0;
               }
               (($0 == "NF") || ($0 == "NF/NF")) {
                 print 0, "NF";
               }
             '                                         |
             sort -k 1,1 -k 2n,2 -k 3n,3               |
             uniq                                      |
             sed -n '1,/1 [0-9]\{1,\} NF$/p'           |
             awk                                       '
               BEGIN {
                 f1_total  = 0;
                 f2_max    = 0;
                 f3_has_nf = 0;
               }
               {
                 f1_total += $1; 
                 if ($1 == 1) {
                   f2_max = ($2 > f2_max) ? $2 : f2_max;
                   f2_vals[$2] = 1;
                 }
                 f3_has_nf = ($3 == "NF") ? 1 : f3_has_nf;
                 cell[NR,1] = $2;
                 if (NF == 3) {
                   cell[NR,2] = $3;
                 }
               }
               END {
                 if ((f1_total == NR) && (f3_has_nf)) {
                   printf("split(\"\",mark);for(i=1;i<=NF;i++){mark[i]=1}");
                   for (i=1; i<f2_max; i++) {
                     if (! (i in f2_vals)) {
                       printf("delete mark[%d];", i);
                     }
                   }
                 } else {
                   printf("split(\"\",mark);");
                   for (i=1; i<=NR; i++) {
                     if (i SUBSEP 2 in cell) {
                       printf("if(%s>%s){for(i=%s;i<=%s;i++){mark[i]=1}}else{for(i=%s;i<=%s;i++){mark[i]=1}}",
                              cell[i,1],cell[i,2],
                              cell[i,2],cell[i,1],
                              cell[i,1],cell[i,2]);
                     } else {
                       if (match(cell[i,1],/^[0-9]+$/) || (cell[i,1] == "NF")) {
                         printf("mark[%s]=1;",cell[i,1]);
                       } else {
                         printf("if(%s>0){mark[%s]=1}",cell[i,1],cell[i,1]);
                       }
                     }
                   }
                 }
                 printf("convert_marked_flds();print;");
               }
             '                                         )
     if echo "$awkc0" | grep -q 'NF'; then
       awkc0b=''
     else
       awkc0b=${awkc0%convert_marked_flds*}
       awkc0='convert_marked_flds();print;'
     fi
     ;;
  *) awkc0='print utf8kata2hira($0);'
     awkc0b=''
     ;;
esac

# === Generate the AWK code for kata2hira operation ==================
awkcode='
BEGIN {
  for (i=0; i<hdr_skip; i++) {
    if (getline line) {
      print line;
    } else {
      exit;
    }
  }
  utf8kata2hira_prep();
  '"$awkc0b"'
}
{
  '"$awkc0"'
}
function convert_marked_flds( fld) {
  for (fld in mark) {
    $fld = utf8kata2hira($fld);
  }
}
function utf8kata2hira_prep( i,l) {

  # register all character codes to shift kana code
  for(i=1;i<=255;i++){chr[i]=sprintf("%c",i);asc[chr[i]]=i;}

  # memorize other values
  offset=14910112; # The previous code of "ァ"
}

function utf8kata2hira(s_in, i,s,s1,s2,utf8c,delta,s_out) {
  s_out = "";
  for (i=1; i<=length(s_in); i++) {
    s = substr(s_in,i,1);
    #if        (s < "\200") {
    #  s_out = s_out s;
    #  continue;
    #}
    if        (s < "\300") {
      s_out = s_out s;
    } else if (s < "\340") {
      i++;
      s_out = s_out s substr(s_in,i,1);
    } else if (s < "\360") {
      s1 = substr(s_in,i+1,1);
      s2 = substr(s_in,i+2,1);
      utf8c = asc[s]*65536 + asc[s1]*256 + asc[s2];
      if        (utf8c<(offset+  1)) { # lower range than "ァ"
        delta=   0;
      } else if (utf8c<(offset+ 32)) { # between "ァ" and "タ"
        delta= 288;
      } else if (utf8c<(offset+224)) { # out of range
        delta=   0;
      } else if (utf8c<(offset+256)) { # between "ダ" and "ミ"
        delta= 480;
      } else if (utf8c<(offset+279)) { # between "ム" and "ヶ"
        delta= 288;
      } else if (utf8c<(offset+285)) { # out of range
        delta=   0;
      } else if (utf8c<(offset+287)) { # between "ヽ" and "ヾ"
        delta= 288;
      } else {
        delta=   0;
      }
      if (delta != 0) {
        utf8c -= delta;
        z = utf8c % 256;
        y = ((utf8c % 65536) - z)/256;
        x = (utf8c - y*256 - z) /65536;
        s_out = s_out chr[x] chr[y] chr[z];
      } else {
        s_out = s_out s s1 s2;
      }
      i += 2;
    } else if (s < "\370") {
      s_out = s_out s substr(s_in,i+1,3);
      i += 3;
    } else if (s < "\374") {
      s_out = s_out s substr(s_in,i+1,4);
      i += 4;
    } else if (s < "\376") {
      s_out = s_out s substr(s_in,i+1,5);
      i += 5;
    } else {
      s_out = s_out s;
    }
  }
  return s_out;
}
'


######################################################################
# Main Routine
######################################################################

case $directmode in
  0) exec awk -v hdr_skip=$opth "$awkcode" ${file:+"$file"};;
  *)      printf '%s' "$directstr"                         |
          awk -v hdr_skip=$opth "$awkcode"                 ;;
esac
