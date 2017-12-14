#!/usr/bin/env bash
########################################################################
#                                                                      #
#               This software is part of the ast package               #
#          Copyright (c) 1985-2013 AT&T Intellectual Property          #
#                      and is licensed under the                       #
#                 Eclipse Public License, Version 1.0                  #
#                    by AT&T Intellectual Property                     #
#                                                                      #
#                A copy of the License is available at                 #
#          http://www.eclipse.org/org/documents/epl-v10.html           #
#         (with md5 checksum b35adb5213ca9657e911e9befb180842)         #
#                                                                      #
#              Information and Software Systems Research               #
#                            AT&T Research                             #
#                           Florham Park NJ                            #
#                                                                      #
#               Glenn Fowler <glenn.s.fowler@gmail.com>                #
#                    David Korn <dgkorn@gmail.com>                     #
#                     Phong Vo <phongvo@gmail.com>                     #
#                                                                      #
########################################################################
: generate getconf and limits info
#
# @(#)conf.sh (AT&T Research) 2011-08-26
#
# this script generates these files from the table file in the first arg
# the remaining args are the C compiler name and flags
#
#	conflim.h	supplemental limits.h definitions
#	conftab.h	readonly string table definitions
#	conftab.c	readonly string table data
#
# you may think it should be simpler
# but you shall be confused anyway
#

case $-:$BASH_VERSION in
*x*:[0123456789]*)	: bash set -x is broken :; set +ex ;;
esac

LC_ALL=C
export LC_ALL

command=conf

shell=`eval 'x=123&&integer n=\${#x}\${x#1?}&&((n==330/(10)))&&echo ksh' 2>/dev/null`

append=0
debug=
extra=0
keep_call='*'
keep_name='*'
trace=
verbose=0
while	:
do	case $1 in
	-a)	append=1 ;;
	-c*)	keep_call=${1#-?} ;;
	-d*)	debug=$1 ;;
	-l)	extra=1 ;;
	-n*)	keep_name=${1#-?} ;;
	-t)	trace=1 ;;
	-v)	verbose=1 ;;
	-*)	echo "Usage: $command [-a] [-ccall-pattern] [-dN] [-l] [-nname_pattern] [-t] [-v] conf.tab" >&2; exit 2 ;;
	*)	break ;;
	esac
	shift
done
head='#include "FEATURE/standards"
#include "FEATURE/common"'
tail="#include <sys/param.h>\n#include <sys/stat.h>"
generated="/* : : generated by $command from $1 : : */"
hdr=
ifs=${IFS-'
	 '}
nl='
'
sp=' '
ob='{'
cb='}'
sym=[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_]*
tmp=conf.tmp
case $verbose:$debug$trace in
1:?*)	echo "$command: debug=$debug trace=$trace keep_call=$keep_call keep_name=$keep_name" >&2 ;;
esac
case $trace in
1)	PS4='+$LINENO+ '; set -x ;;
esac

case $# in
0)	case $extra in
	0)	echo "$command: table argument expected" >&2
		exit 1
		;;
	esac
	tab=/dev/null
	;;
*)	tab=$1
	shift
	if	test ! -f $tab
	then	echo "$command: $tab: cannot read" >&2
		exit 1
	fi
	;;
esac
case $# in
0)	cc=cc ;;
*)	cc=$* ;;
esac

rm -f $tmp.*
case $debug in
'')	trap "code=\$?; rm -f $tmp.*; exit \$code" 0 1 2 ;;
esac

# determine the intmax_t printf format

cat > $tmp.c <<!
${head}
int
main()
{
#if _ast_intmax_long
	return 1;
#else
	return 0;
#endif
}
!
if	$cc -o $tmp.exe $tmp.c >/dev/null 2>&1 && ./$tmp.exe
then	LL_format='ll'
else	LL_format='l'
fi

# determine the intmax_t constant suffix

cat > $tmp.c <<!
${head}
int
main()
{
#if _ast_intmax_long
	return 1;
#else
	_ast_intmax_t		s = 0x7fffffffffffffffLL;
	unsigned _ast_intmax_t	u = 0xffffffffffffffffLL;

	return 0;
#endif
}
!
if	$cc -o $tmp.exe $tmp.c >/dev/null 2>&1
then	if	./$tmp.exe
	then	LL_suffix='LL'
	else	LL_suffix='L'
	fi
else	LL_suffix=''
fi

cat > $tmp.c <<!
${head}
int
main()
{
	unsigned int	u = 1U;
	unsigned int	ul = 1UL;

	return 0;
}
!
if	$cc -o $tmp.exe $tmp.c >/dev/null 2>&1
then	U_suffix='U'
else	U_suffix=''
fi

# set up the names and keys

keys=
standards=

case $append$extra in
00)	case $verbose in
	1)	echo "$command: read $tab" >&2 ;;
	esac
	exec < $tab
	while	:
	do	IFS=""
		read line
		eof=$?
		IFS=$ifs
		case $eof in
		0)	;;
		*)	break ;;
		esac
		case $line in
		""|\#*)	;;
		*)	set x $line
			shift; name=$1
			shift; standard=$1
			shift; call=$1
			shift; section=$1
			shift; flags=$1
			alternates=
			define=
			values=
			script=
			headers=
			while	:
			do	shift
				case $# in
				0)	break ;;
				esac
				case $1 in
				":")	shift
					eval script='$'script_$1
					break
					;;
				*"{")	case $1 in
					"sh{")	script="# $name" ;;
					*)	script= ;;
					esac
					shift
					args="$*"
					IFS=""
					while	read line
					do	case $line in
						"}")	break ;;
						esac
						script=$script$nl$line
					done
					IFS=$ifs
					break
					;;
				*.h)	case $shell in
					ksh)	f=${1%.h} ;;
					*)	f=`echo $1 | sed 's,\.h$,,'` ;;
					esac
					case " $hdr " in
					*" $f "*)
						headers=$headers$nl#include$sp'<'$1'>'
						;;
					*" -$f- "*)
						;;
					*)	if	iffe -n - hdr $f | grep _hdr_$f >/dev/null
						then	hdr="$hdr $f"
							headers=$headers$nl#include$sp'<'$1'>'
						else	hdr="$hdr -$f-"
						fi
						;;
					esac
					;;
				*)	values=$values$sp$1
					case $1 in
					$sym)	echo "$1" >> $tmp.v ;;
					esac
					;;
				esac
			done
			case " $standards " in
			*" $standard "*)
				;;
			*)	standards="$standards $standard"
				;;
			esac
			case $name:$flags in
			*:*S*)	;;
			VERSION)flags="${flags}S" ;;
			esac
			case $name in
			*VERSION*)key=${standard}${section} ;;
			*)	  key= ;;
			esac
			case $key in
			''|*_)	key=${key}${name} ;;
			*)	key=${key}_${name} ;;
			esac
			eval sys='$'CONF_call_${key}
			case $sys in
			?*)	call=$sys ;;
			esac
			case $call in
			SI)	sys=CS ;;
			*)	sys=$call ;;
			esac
			key=${sys}_${key}
			keys="$keys$nl$key"
			eval CONF_name_${key}='$'name
			eval CONF_standard_${key}='$'standard
			eval CONF_call_${key}='$'call
			eval CONF_section_${key}='$'section
			eval CONF_flags_${key}='$'flags
			eval CONF_define_${key}='$'define
			eval CONF_values_${key}='$'values
			eval CONF_script_${key}='$'script
			eval CONF_args_${key}='$'args
			eval CONF_headers_${key}='$'headers
			eval CONF_keys_${name}=\"'$'CONF_keys_${name} '$'key\"
			;;
		esac
	done
	;;
esac
case $debug in
-d1)	for key in $keys
	do	eval name=\"'$'CONF_name_$key\"
		case $name in
		?*)	eval standard=\"'$'CONF_standard_$key\"
			eval call=\"'$'CONF_call_$key\"
			eval section=\"'$'CONF_section_$key\"
			eval flags=\"'$'CONF_flags_$key\"
			eval define=\"'$'CONF_define_$key\"
			eval values=\"'$'CONF_values_$key\"
			eval script=\"'$'CONF_script_$key\"
			eval args=\"'$'CONF_args_$key\"
			eval headers=\"'$'CONF_headers_$key\"
			printf "%29s %35s %8s %2s %1d %5s %s$nl" "$name" "$key" "$standard" "$call" "$section" "$flags" "$define${values:+$sp=$values}${headers:+$sp$headers$nl}${script:+$sp$ob$script$nl$cb}"
			;;
		esac
	done
	exit
	;;
esac

systeminfo='
#if !defined(SYS_NMLEN)
#define SYS_NMLEN	9
#endif
#include <sys/systeminfo.h>'
echo "$systeminfo" > $tmp.c
$cc -E $tmp.c >/dev/null 2>&1 || systeminfo=

# check for native getconf(1)

CONF_getconf=
CONF_getconf_a=
for d in /usr/bin /bin /usr/sbin /sbin
do	if	test -x $d/getconf
	then	case `$d/getconf --?-version 2>&1` in
		*"AT&T"*"Research"*)
			: presumably an implementation also configured from conf.tab
			;;
		*)	CONF_getconf=$d/getconf
			if	$CONF_getconf -a >/dev/null 2>&1
			then	CONF_getconf_a=-a
			fi
			;;
		esac
		break
	fi
done
export CONF_getconf CONF_getconf_a

case $verbose in
1)	echo "$command: check ${CONF_getconf:+$CONF_getconf(1),}confstr(2),pathconf(2),sysconf(2),sysinfo(2) configuration names" >&2 ;;
esac
{
	echo "#include <unistd.h>$systeminfo
int i = 0;" > $tmp.c
	$cc -E $tmp.c
} |
sed \
	-e '/^#[^0123456789]*1[ 	]*".*".*/!d' \
	-e 's/^#[^0123456789]*1[ 	]*"\(.*\)".*/\1/' |
sort -u > $tmp.f
{
sed \
	-e 's/[^ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789]/ /g' \
	-e 's/[ 	][ 	]*/\n/g' \
	`cat $tmp.f` 2>/dev/null |
	egrep '^(SI|_(CS|PC|SC|SI))_.'
	case $CONF_getconf_a in
	?*)	$CONF_getconf $CONF_getconf_a | sed 's,[=:    ].*,,'
		;;
	*)	case $CONF_getconf in
		?*)	for v in `strings $CONF_getconf | grep '^[ABCDEFGHIJKLMNOPQRSTUVWXYZ_][ABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789]*$'`
			do	if	$CONF_getconf $v >/dev/null
				then	echo $v
				fi
			done
			;;
		esac
		;;
	esac 2>/dev/null
} |
egrep -v '^_[ABCDEFGHIJKLMNOPQRSTUVWXYZ]+_(COUNT|LAST|N|STR)$' |
sort -u > $tmp.g
{
	grep '^_' $tmp.g
	grep '^[^_]' $tmp.g
} > $tmp.t
mv $tmp.t $tmp.g
case $debug in
-d2)	exit ;;
esac

HOST=`package | sed -e 's,[0123456789.].*,,' | tr abcdefghijklmnopqrstuvwxyz ABCDEFGHIJKLMNOPQRSTUVWXYZ`
case $HOST in
'')	HOST=SYSTEM ;;
esac

exec < $tmp.g

while	read line
do	flags=F
	section=
	underscore=
	define=$line
	IFS=_
	set $line
	IFS=$ifs
	case $1 in
	'')	case $# in
		0)	continue ;;
		esac
		shift
		;;
	esac
	case $1 in
	CS|PC|SC|SI)
		call=$1
		shift
		standard=$1
		;;
	*)	flags=${flags}R
		standard=$1
		while	:
		do	case $# in
			0)	continue 2 ;;
			esac
			shift
			case $1 in
			CS|PC|SC|SI)
				call=$1
				shift
				break
				;;
			O|o|OLD|old)
				continue 2
				;;
			esac
			standard=${standard}_$1
		done
		;;
	esac
	case $1 in
	SET)	continue ;;
	esac
	case $standard in
	_*)	standard=`echo $standard | sed 's,^_*,,'` ;;
	esac
	case " $standards " in
	*" $standard "*)
		;;
	*)	case $standard in
		[0123456789]*)
			section=$standard
			standard=POSIX
			;;
		*[0123456789])
			eval `echo $standard | sed 's,\(.*\)\([0123456789]*\),standard=\1 section=\2,'`
			;;
		esac
		;;
	esac
	case $flags in
	*R*)	case $call in
		SI)	;;
		*)	underscore=U ;;
		esac
		;;
	*)	case " $standards " in
		" C ")	shift
			;;
		*" $standard "*)
			case $call in
			SI)	;;
			*)	flags=${flags}P
				underscore=U
				;;
			esac
			shift
			;;
		*)	standard=
			;;
		esac
		;;
	esac
	case $standard in
	'')	standard=$HOST
		case $call in
		SI)	;;
		*)	underscore=U ;;
		esac
		case $call in
		CS|PC|SC)
			case $define in
			_${call}_*)
				standard=POSIX
				;;
			esac
			;;
		esac
		;;
	esac
	part=$section
	case $section in
	'')	section=1
		case $standard in
		POSIX|XOPEN) part=$section ;;
		esac
		;;
	esac
	name=
	while	:
	do	case $# in
		0)	break ;;
		esac
		case $name in
		'')	name=$1 ;;
		*)	name=${name}_$1 ;;
		esac
		shift
	done
	case $name in
	'')	;;
	CONFORMANCE|FS_3D|HOSTTYPE|LIBPATH|LIBPREFIX|LIBSUFFIX|PATH_ATTRIBUTES|PATH_RESOLVE|UNIVERSE)
		;;
	*)	values=
		script=
		args=
		headers=
		case $name in
		V[123456789]_*|V[123456789][0123456789]_*)	underscore=VW ;;
		esac
		case $call in
		CS|SI)	key=CS ;;
		*)	key=$call ;;
		esac
		case $name in
		*VERSION*)key=${key}_${standard}${part} ;;
		esac
		key=${key}_${name}
		eval x='$'CONF_keys_$name
		case $x in
		'')	eval x='$'CONF_name_$key
			case $x in
			'')	case $call in
				SI)	flags=O$flags ;;
				esac
				case $underscore in
				?*)	flags=${flags}${underscore} ;;
				esac
				old=QQ
				case $name in
				*VERSION*)old=${old}_${standard}${part} ;;
				esac
				old=${old}_${name}
				eval x='$'CONF_name_$old
				case $x in
				?*)	eval CONF_name_$old=
					eval flags='$'flags'$'CONF_flags_$old
					eval values='$'CONF_values_$old
					eval script='$'CONF_script_$old
					eval args='$'CONF_args_$old
					eval headers='$'CONF_headers_$old
					;;
				esac
				keys="$keys$nl$key"
				eval CONF_name_${key}='$'name
				eval CONF_standard_${key}='$'standard
				eval CONF_call_${key}='$'call
				eval CONF_section_${key}='$'section
				eval CONF_flags_${key}=d'$'flags
				eval CONF_define_${key}='$'define
				eval CONF_values_${key}='$'values
				eval CONF_script_${key}='$'script
				eval CONF_args_${key}='$'args
				eval CONF_headers_${key}='$'headers
				;;
			*)	eval x='$'CONF_define_$key
				case $x in
				?*)	case $call in
					CS)	eval x='$'CONF_call_$key
						case $x in
						SI)	;;
						*)	define= ;;
						esac
						;;
					*)	define=
						;;
					esac
					;;
				esac
				case $define in
				?*)	eval CONF_define_${key}='$'define
					eval CONF_call_${key}='$'call
					eval x='$'CONF_call_${key}
					case $x in
					QQ)	;;
					*)	case $flags in
						*R*)	flags=R ;;
						*)	flags= ;;
						esac
						;;
					esac
					case $call in
					SI)	flags=O$flags ;;
					esac
					eval CONF_flags_${key}=d'$'flags'$'CONF_flags_${key}
					;;
				esac
				old=QQ
				case $name in
				*VERSION*)old=${old}_${standard}${part} ;;
				esac
				old=${old}_${name}
				eval CONF_name_$old=
			esac
			;;
		*)	for key in $x
			do	eval x='$'CONF_call_${key}
				case $x in
				XX)	eval CONF_call_${key}=QQ
					eval CONF_flags_${key}=S'$'CONF_flags_${key}
					;;
				esac
			done
		esac
		;;
	esac
done

# sort keys by name

keys=`for key in $keys
do	eval echo '$'CONF_name_$key '$'key
done | sort -u | sed 's,.* ,,'`
case $debug in
-d3)	for key in $keys
	do	eval name=\"'$'CONF_name_$key\"
		case $name in
		?*)	eval standard=\"'$'CONF_standard_$key\"
			eval call=\"'$'CONF_call_$key\"
			eval section=\"'$'CONF_section_$key\"
			eval flags=\"'$'CONF_flags_$key\"
			eval define=\"'$'CONF_define_$key\"
			eval values=\"'$'CONF_values_$key\"
			eval script=\"'$'CONF_script_$key\"
			eval headers=\"'$'CONF_headers_$key\"
			printf "%29s %35s %8s %2s %1d %5s %s$nl" "$name" "$key" "$standard" "$call" "$section" "$flags" "$define${values:+$sp=$values}${headers:+$sp$headers$nl}${script:+$sp$ob$script$nl$cb}"
			;;
		esac
	done
	exit
	;;
esac

# mark the dups CONF_PREFIXED

prev_key=
prev_name=
for key in $keys
do	eval name=\"'$'CONF_name_$key\"
	case $name in
	'')	continue
		;;
	$prev_name)
		eval p='$'CONF_flags_${prev_key}
		eval c='$'CONF_flags_${key}
		case $p:$c in
		*L*:*L*);;
		*L*:*)	c=L${c} ;;
		*:*L*)	p=L${p} ;;
		*)	p=P$p c=P$c ;;
		esac
		eval CONF_flags_${prev_key}=$p
		eval CONF_flags_${key}=$c
		;;
	esac
	prev_name=$name
	prev_key=$key
done

# collect all the macros/enums

for key in $keys
do	eval name=\"'$'CONF_name_$key\"
	case $name in
	'')		continue ;;
	$keep_name)	;;
	*)		continue ;;
	esac
	eval call=\"'$'CONF_call_$key\"
	case $call in
	$keep_call)	;;
	*)		continue ;;
	esac
	eval standard=\"'$'CONF_standard_$key\"
	eval section=\"'$'CONF_section_$key\"
	eval flags=\"'$'CONF_flags_$key\"
	eval define=\"'$'CONF_define_$key\"
	eval values=\"'$'CONF_values_$key\"
	eval script=\"'$'CONF_script_$key\"
	eval args=\"'$'CONF_args_$key\"
	eval headers=\"'$'CONF_headers_$key\"
	conf_name=$name
	case $call in
	QQ)	call=XX
		for c in SC PC CS
		do	case $flags in
			*S*)	case $section in
				1)	eval x='$'CONF_call_${c}_${standard}_${name} ;;
				*)	eval x='$'CONF_call_${c}_${standard}${section}_${name} ;;
				esac
				;;
			*)	eval x='$'CONF_call_${c}_${name}
				;;
			esac
			case $x in
			?*)	call=$x
				break
				;;
			esac
		done
		case $call in
		XX)	for c in SC PC CS
			do	echo "_${c}_${name}"
				case $flags in
				*S*)	case $section in
					1)	echo "_${c}_${standard}_${name}" ;;
					*)	echo "_${c}_${standard}${section}_${name}" ;;
					esac
					;;
				esac
			done
			;;
		esac
		;;
	esac
	case $call in
	CS|PC|SC|SI|XX)
		;;
	*)	echo "$command: $name: $call: invalid call" >&2
		exit 1
		;;
	esac
	case $flags in
	*[ABEGHIJQTYZabcefghijklmnopqrstuvwxyz_123456789]*)
		echo "$command: $name: $flags: invalid flag(s)" >&2
		exit 1
		;;
	esac
	case $section in
	[01])	;;
	*)	case $flags in
		*N*)	;;
		*)	name=${section}_${name} ;;
		esac
		standard=${standard}${section}
		;;
	esac
	case $call in
	XX)	;;
	*)	case $flags in
		*d*)	conf_op=${define} ;;
		*O*)	conf_op=${call}_${name} ;;
		*R*)	conf_op=_${standard}_${call}_${name} ;;
		*S*)	conf_op=_${call}_${standard}_${name} ;;
		*)	conf_op=_${call}_${name} ;;
		esac
		echo "${conf_op}"
		;;
	esac
	case $standard:$flags in
	C:*)	;;
	*:*L*)	echo "${conf_name}"
		echo "_${standard}_${conf_name}"
		;;
	*:*M*)	case $section in
		1)	echo "_${standard}_${conf_name}" ;;
		*)	echo "_${standard}${section}_${conf_name}" ;;
		esac
		;;
	esac
done > $tmp.q
sort -u < $tmp.q > $tmp.t
mv $tmp.t $tmp.q
sort -u < $tmp.v > $tmp.t
mv $tmp.t $tmp.v
case $debug in
-d4)	exit ;;
esac

# test all the macros in a few batches (some compilers have an error limit)

defined() # list-file
{
	: > $tmp.p
	while	:
	do	{
			cat <<!
${head}
#include <sys/types.h>
#include <limits.h>
#include <unistd.h>$systeminfo$headers
${tail}
#undef conf
unsigned int conf[] = {
!
			sed 's/$/,/' $1
			echo "};"
		} > $tmp.c
		[ -f $tmp.1.c ] || cp $tmp.c $tmp.1.c
		if	$cc -c $tmp.c > $tmp.e 2>&1
		then	break
		fi
		[ -f $tmp.1.e ] || cp $tmp.e $tmp.1.e
		snl='\
'
		sed "s/[^_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789][^_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789]*/${snl}/g" $tmp.e |
		grep '^[_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz][_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789]*$' |
		sort -u > $tmp.n
		cmp -s $tmp.n $tmp.p && break
		fgrep -x -v -f $tmp.n $1 > $tmp.y
		mv $tmp.y $1
		mv $tmp.n $tmp.p
	done
	{
		cat <<!
${head}
#include <sys/types.h>
#include <limits.h>
#include <unistd.h>$systeminfo$headers
${tail}
#undef conf
!
		sed 's/.*/conf "&" = &/' $1
	} > $tmp.c
	$cc -E $tmp.c 2>/dev/null |
	sed -e '/conf[ 	]*".*"[ 	]*=[ 	]*/!d' -e '/[_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789][ 	]*(/!d' -e 's/.*"\(.*\)".*/\1/' > $tmp.n
	if	test -s $tmp.n
	then	fgrep -x -v -f $tmp.n $1 > $tmp.y
		mv $tmp.y $1
	fi
}

case $verbose in
1)	echo "$command: check macros/enums as static initializers" >&2 ;;
esac
defined $tmp.q
defined $tmp.v
case $debug in
-d5)	exit ;;
esac

# mark the constant macros/enums

exec < $tmp.q
while	read line
do	eval CONF_const_${line}=1
done
exec < $tmp.v
while	read line
do	eval CONF_const_${line}=1
done

# mark the string literal values

{
	cat <<!
${head}
#include <sys/types.h>
#include <limits.h>
#include <unistd.h>$systeminfo$headers
${tail}
#undef conf
!
	sed 's/.*/conf "&" = &/' $tmp.q
} > $tmp.c
$cc -E $tmp.c 2>/dev/null |
sed -e '/conf[ 	]*".*"[ 	]*=[ 	]*"/!d' -e 's/.*"\([^"]*\)".*/\1/' > $tmp.e
exec < $tmp.e
while	read line
do	eval CONF_string_${line}=1
done

# walk through the table

case $shell in
ksh)	integer len name_max ;;
esac
name_max=1
export tmp name standard call cc

exec > $tmp.t
for key in $keys
do	eval name=\"'$'CONF_name_$key\"
	case $name in
	'')		continue ;;
	$keep_name)	;;
	*)		continue ;;
	esac
	eval call=\"'$'CONF_call_$key\"
	case $call in
	$keep_call)	;;
	*)		continue ;;
	esac
	eval standard=\"'$'CONF_standard_$key\"
	eval section=\"'$'CONF_section_$key\"
	eval flags=\"'$'CONF_flags_$key\"
	eval define=\"'$'CONF_define_$key\"
	eval values=\"'$'CONF_values_$key\"
	eval script=\"'$'CONF_script_$key\"
	eval args=\"'$'CONF_args_$key\"
	eval headers=\"'$'CONF_headers_$key\"
	conf_name=$name
	case $call in
	QQ)	call=XX
		for c in SC PC CS
		do	case $flags in
			*S*)	case $section in
				1)	eval x='$'CONF_call_${c}_${standard}_${name} ;;
				*)	eval x='$'CONF_call_${c}_${standard}${section}_${name} ;;
				esac
				;;
			*)	eval x='$'CONF_call_${c}_${name}
				;;
			esac
			case $x in
			?*)	call=$x
				break
				;;
			esac
		done
		case $call in
		XX)	for c in SC PC CS
			do	case $flags in
				*S*)	case $section in
					1)	eval x='$'CONF_const__${c}_${standard}_${name} ;;
					*)	eval x='$'CONF_const__${c}_${standard}${section}_${name} ;;
					esac
					;;
				*)	eval x='$'CONF_const__${c}_${name}
					;;
				esac
				case $x in
				1)	call=$c
					break
					;;
				esac
			done
			;;
		esac
		case $call in
		XX)	case $standard in
			C)	standard=POSIX ;;
			esac
			case $flags in
			*L*)	flags=lFU ;;
			*)	flags=FU ;;
			esac
			;;
		esac
		;;
	esac
	case " $standards " in
	*" $standard "*)
		;;
	*)	standards="$standards $standard"
		;;
	esac
	conf_standard=CONF_${standard}
	case $call in
	CS)	conf_call=CONF_confstr
		;;
	PC)	conf_call=CONF_pathconf
		;;
	SC)	conf_call=CONF_sysconf
		;;
	SI)	conf_call=CONF_sysinfo
		;;
	XX)	conf_call=CONF_nop
		;;
	esac
	conf_op=-1
	for s in _${call}_${standard}${section}_${name} _${call}_${standard}_${name} _${call}_${section}_${name} _${call}_${name} ${call}_${name}
	do	eval x='$'CONF_const_${s}
		case $x in
		1)	conf_op=${s}
			break
			;;
		esac
	done
	conf_section=$section
	conf_flags=0
	case $flags in
	*C*)	conf_flags="${conf_flags}|CONF_DEFER_CALL" ;;
	esac
	case $flags in
	*D*)	conf_flags="${conf_flags}|CONF_DEFER_MM" ;;
	esac
	case $flags in
	*F*)	conf_flags="${conf_flags}|CONF_FEATURE" ;;
	esac
	case $flags in
	*L*)	conf_flags="${conf_flags}|CONF_LIMIT" ;;
	esac
	case $flags in
	*M*)	conf_flags="${conf_flags}|CONF_MINMAX" ;;
	esac
	case $flags in
	*N*)	conf_flags="${conf_flags}|CONF_NOSECTION" ;;
	esac
	case $flags in
	*P*)	conf_flags="${conf_flags}|CONF_PREFIXED" ;;
	esac
	case $flags in
	*S*)	conf_flags="${conf_flags}|CONF_STANDARD" ;;
	esac
	case $flags in
	*U*)	conf_flags="${conf_flags}|CONF_UNDERSCORE" ;;
	esac
	case $flags in
	*V*)	conf_flags="${conf_flags}|CONF_NOUNDERSCORE" ;;
	esac
	case $flags in
	*W*)	conf_flags="${conf_flags}|CONF_PREFIX_ONLY" ;;
	esac
	case $debug in
	?*)	case $standard in
		????)	sep=" " ;;
		???)	sep="  " ;;
		??)	sep="   " ;;
		?)	sep="    " ;;
		*)	sep="" ;;
		esac
		echo "$command: test: $sep$standard $call $name" >&2
		;;
	esac
	case $call in
	CS|SI)	conf_flags="${conf_flags}|CONF_STRING"
		string=1
		;;
	*)	eval string='$'CONF_string_${key}
		;;
	esac
	conf_limit=0
	case $flags in
	*[Ll]*)	d=
		case ${conf_name} in
		LONG_MAX|SSIZE_MAX)
			x=
			;;
		*)	eval x='$'CONF_const_${conf_name}
			;;
		esac
		case $x in
		'')	for s in ${values}
			do	case $s in
				$sym)	eval x='$'CONF_const_${s}
					case $x in
					1)	eval a='$'CONF_const_${standard}_${s}
						case $a in
						$x)	x= ;;
						*)	x=$s ;;
						esac
						break
						;;
					esac
					;;
				[0123456789]*|[-+][0123456789]*)
					d=$s
					break
					;;
				esac
			done
			case ${x:+1}:$flags:$conf_op in
			:*:-1|:*X*:*)
				case $verbose in
				1)	echo "$command: probe for ${conf_name} <limits.h> value" >&2 ;;
				esac
				x=
				case $CONF_getconf in
				?*)	if	$CONF_getconf $conf_name > $tmp.x 2>/dev/null
					then	x=`cat $tmp.x`
						case $x in
						undefined)	x= ;;
						esac
					fi
					;;
				esac
				case ${x:+1} in
				'')	case $script in
					'#'*)	echo "$script" > $tmp.sh
						chmod +x $tmp.sh
						x=`./$tmp.sh 2>/dev/null`
						;;
					'')	case $conf_name in
						SIZE_*|U*|*_MAX)	
							f="%${LL_format}u"
							t="unsigned _ast_intmax_t"
							;;
						*)	f="%${LL_format}d"
							t="_ast_intmax_t"
							;;
						esac
						cat > $tmp.c <<!
${head}
#include <stdio.h>
#include <sys/types.h>
#include <limits.h>
#include <unistd.h>$systeminfo$headers
${tail}
int
main()
{
	printf("$f\n", ($t)$conf_name);
	return 0;
}
!
						;;
					*)	cat > $tmp.c <<!
${head}
#include <stdio.h>
#include <sys/types.h>
#include <limits.h>
#include <unistd.h>$systeminfo$headers
${tail}
${script}
!
						;;
					esac
					case $args in
					'')	set "" ;;
					*)	eval set '""' '"'$args'"'; shift ;;
					esac
					for a
					do	case $script in
						'#'*)	./$tmp.sh $a > $tmp.x 2>/dev/null
							x=$?
							;;
						*)	$cc $a -o $tmp.exe $tmp.c >/dev/null 2>&1 && ./$tmp.exe > $tmp.x 2>/dev/null
							x=$?
							;;
						esac
						case $x in
						0)	x=`cat $tmp.x`
							case $x in
							"-")	x=$a ;;
							esac
							break
							;;
						*)	x=
							;;
						esac
					done
					;;
				esac
				case $x in
				'')	x=$d ;;
				esac
				;;
			esac
			case ${x:+1}:$flags:$conf_op in
			1:*:-1|1:*X*:*)
				conf_limit=$x
				case $flags in
				*L*)	;;
				*)	conf_flags="${conf_flags}|CONF_LIMIT" ;;
				esac
				conf_flags="${conf_flags}|CONF_LIMIT_DEF"
				case $string:$x in
				1:*)	cat >> $tmp.l <<!
printf("#ifndef ${conf_name}\n");
printf("#define ${conf_name} \"${x}\"\n");
printf("#endif\n");
!
					;;
				*:U*)	cat >> $tmp.l <<!
printf("#ifndef ${conf_name}\n");
printf("#ifndef ${x}\n");
printf("#define ${x} %lu\n", (unsigned long)(${x}));
printf("#endif\n");
printf("#define ${conf_name} ${x}\n");
printf("#endif\n");
!
					;;
				*:$sym)	cat >> $tmp.l <<!
printf("#ifndef ${conf_name}\n");
printf("#ifndef ${x}\n");
printf("#define ${x} %ld\n", (long)(${x}));
printf("#endif\n");
printf("#define ${conf_name} ${x}\n");
printf("#endif\n");
!
					;;
				*)	cat >> $tmp.l <<!
printf("#ifndef ${conf_name}\n");
printf("#define ${conf_name} ${x}\n");
printf("#endif\n");
!
					;;
				esac
				;;
			esac
			;;
		esac
		;;
	esac
	case $section in
	[01])	;;
	*)	case $flags in
		*N*)	;;
		*)	name=${section}_${name} ;;
		esac
		standard=${standard}${section}
		;;
	esac
	conf_minmax=0
	case $call:$standard:$flags in
	*:C:*M*)for s in _${standard}_${conf_name} ${values}
		do	case $s in
			$sym)	;;
			*)	conf_minmax=$s
				conf_flags="${conf_flags}|CONF_MINMAX_DEF"
				break
				;;
			esac
		done
		;;
	*:C:*)	;;
	[CPSX][CSX]:*:*[FM]*)
		x=
		for s in _${standard}_${conf_name} ${values}
		do	case $s in
			$sym)	eval x='$'CONF_const_${s} ;;
			*)	x=1 ;;
			esac
			case $x in
			1)	conf_minmax=$s
				case $flags in
				*M*)	conf_flags="${conf_flags}|CONF_MINMAX_DEF" ;;
				esac
				case $conf_minmax in
				[-+0123456789]*)	x= ;;
				esac
				break
				;;
			esac
		done
		case ${x:+1}:${script:+1} in
		:1)	case $verbose in
			1)	echo "$command: probe for _${standard}_${conf_name} minmax value" >&2 ;;
			esac
			case $CONF_getconf in
			?*)	if	$CONF_getconf _${standard}_${conf_name} > $tmp.x 2>/dev/null
				then	x=`cat $tmp.x`
					case $x in
					undefined)	x= ;;
					esac
				fi
				;;
			esac
			case $x in
			'')	case $script in
				'#'*)	echo "$script" > $tmp.sh
					chmod +x $tmp.sh
					x=`./$tmp.sh 2>/dev/null`
					;;
				*)	cat > $tmp.c <<!
${head}
#include <sys/types.h>
#include <limits.h>
#include <unistd.h>$systeminfo$headers
${tail}
${script}
!
					;;
				esac
				case $args in
				'')	set "" ;;
				*)	eval set '""' "$args"; shift ;;
				esac
				for a
				do	case $script in
					'#'*)	./$tmp.sh $a > $tmp.x 2>/dev/null
						x=$?
						;;
					*)	$cc $a -o $tmp.exe $tmp.c >/dev/null 2>&1 && ./$tmp.exe > $tmp.x 2>/dev/null
						x=$?
						;;
					esac
					case $x in
					0)	x=`cat $tmp.x`
						case $x in
						"-")	x=$a ;;
						esac
						break
						;;
					*)	x=
						;;
					esac
				done
				;;
			esac
			case $x in
			?*)	conf_minmax=$x
				case $flags in
				*M*)	case "|$conf_flags|" in
					*'|CONF_MINMAX_DEF|'*)
						;;
					*)	conf_flags="${conf_flags}|CONF_MINMAX_DEF"
						;;
					esac
					;;
				esac
				;;
			esac
			;;
		esac
		;;
	esac
	case $string in
	1)	conf_limit="{ 0, $conf_limit }" conf_minmax="{ 0, $conf_minmax }"
		;;
	*)	case $conf_limit in
		0[xX]*|-*|+*|[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_]*)
			;;
		*[!0123456789abcdefABCDEF]*)
			conf_limit=0
			;;
		*[!0123456789]*)
			conf_limit=0x$conf_limit
			;;
		esac
		case $conf_minmax in
		0[xX]*|-*|+*|[ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_]*)
			;;
		*[!0123456789abcdefABCDEF]*)
			conf_minmax=0
			;;
		*[!0123456789]*)
			conf_minmax=0x$conf_minmax
			;;
		esac
		case $conf_limit in
		?*[-+]*|*['()']*)
			;;
		*[lLuU])
			case $LL_suffix in
			??)	case $conf_limit in
				*[!lL][lL]|*[!lL][lL][uU])
					conf_limit=${conf_limit}L
					;;
				esac
				;;
			esac
			;;
		-*[2468])	
			case $shell in
			ksh)	p=${conf_limit%?}
				s=${conf_limit#$p}
				((s=s-1))
				;;
			*)	eval `echo '' $conf_limit | sed 's/ *\(.*\)\(.\) */p=\1 s=\2/'`
				s=`expr $s - 1`
				;;
			esac
			conf_limit=${p}${s}${LL_suffix}-1${LL_suffix}
			;;
		0[xX]*[abcdefABCDEF])
			conf_limit=${conf_limit}${LL_suffix}
			;;
		-*[0123456789])
			conf_limit=${conf_limit}${LL_suffix}
			;;
		*[0123456789])
			conf_limit=${conf_limit}${U_suffix}${LL_suffix}
			;;
		esac
		case $conf_minmax in
		?*[-+]*|*['()']*)
			;;
		*[lLuU])
			case $LL_suffix in
			??)	case $conf_minmax in
				*[!lL][lL]|*[!lL][lL][uU])
					conf_minmax=${conf_minmax}L
					;;
				esac
				;;
			esac
			;;
		-*[2468])	
			case $shell in
			ksh)	p=${conf_minmax%?}
				s=${conf_minmax#$p}
				((s=s-1))
				;;
			*)	eval `echo '' $conf_minmax | sed 's/ *\(.*\)\(.\) */p=\1 s=\2/'`
				s=`expr $s - 1`
				;;
			esac
			conf_minmax=${p}${s}${LL_suffix}-1${LL_suffix}
			;;
		0[xX]*[abcdefABCDEF])
			conf_minmax=${conf_minmax}${LL_suffix}
			;;
		-*[0123456789])
			conf_minmax=${conf_minmax}${LL_suffix}
			;;
		*[0123456789])
			conf_minmax=${conf_minmax}${U_suffix}${LL_suffix}
			;;
		esac
		conf_limit="{ $conf_limit, 0 }" conf_minmax="{ $conf_minmax, 0 }"
		;;
	esac
	case $conf_flags in
	'0|'*)	case $shell in
		ksh)	conf_flags=${conf_flags#0?} ;;
		*)	conf_flags=`echo "$conf_flags" | sed 's/^0.//'` ;;
		esac
		;;
	esac
	echo "{ \"$conf_name\", $conf_limit, $conf_minmax, $conf_flags, $conf_standard, $conf_section, $conf_call, $conf_op },"
	case $shell in
	ksh)	len=${#conf_name}
		if	((len>=name_max))
		then	((name_max=len+1))
		fi
		;;
	*)	len=`echo ${conf_name} | wc -c`
		if	expr \( $len - 1 \) \>= ${name_max} >/dev/null
		then	name_max=$len
		fi
		;;
	esac
done
exec > /dev/null
case $debug in
-d6)	exit ;;
esac

# conf string table

base=conftab
case $verbose in
1)	echo "$command: generate ${base}.h string table header" >&2 ;;
esac
case $shell in
ksh)	((name_max=name_max+3)); ((name_max=name_max/4*4)) ;; # bsd /bin/sh !
*)	name_max=`expr \( $name_max + 3 \) / 4 \* 4` ;;
esac
{
cat <<!
#ifndef _CONFTAB_H
#define _CONFTAB_H
$systeminfo

${generated}

#if !defined(const) && !defined(__STDC__) && !defined(__cplusplus) && !defined(c_plusplus)
#define const
#endif

#define conf		_ast_conf_data
#define conf_elements	_ast_conf_ndata

#define prefix		_ast_conf_prefix
#define prefix_elements	_ast_conf_nprefix

#define CONF_nop	0
#define	CONF_confstr	1
#define CONF_pathconf	2
#define CONF_sysconf	3
#define CONF_sysinfo	4

!
index=0
for standard in $standards
do	echo "#define CONF_${standard}	${index}"
	case $shell in
	ksh)	((index=index+1)) ;;
	*)	index=`expr ${index} + 1` ;;
	esac
done
echo "#define CONF_call	${index}"
case $CONF_getconf in
?*)	echo
	echo "#define _pth_getconf	\"$CONF_getconf\""
	case $CONF_getconf_a in
	?*)	echo "#define _pth_getconf_a	\"$CONF_getconf_a\"" ;;
	esac
	;;
esac
cat <<!

#define CONF_DEFER_CALL		0x0001
#define CONF_DEFER_MM		0x0002
#define CONF_FEATURE		0x0004
#define CONF_LIMIT		0x0008
#define CONF_LIMIT_DEF		0x0010
#define CONF_MINMAX		0x0020
#define CONF_MINMAX_DEF		0x0040
#define CONF_NOSECTION		0x0080
#define CONF_NOUNDERSCORE	0x0100
#define CONF_PREFIX_ONLY	0x0200
#define CONF_PREFIXED		0x0400
#define CONF_STANDARD		0x0800
#define CONF_STRING		0x1000
#define CONF_UNDERSCORE		0x2000
#define CONF_USER		0x4000

struct Conf_s; typedef struct Conf_s Conf_t;

typedef struct Value_s
{
	intmax_t	number;
	const char*	string;
} Value_t;

struct Conf_s
{
	const char	name[${name_max}];
	Value_t		limit;
	Value_t		minmax;
	unsigned int	flags;
	short		standard;
	short		section;
	short		call;
	short		op;
};

typedef struct Prefix_s
{
	const char	name[16];
	short		length;
	short		standard;
	short		call;
} Prefix_t;

extern const Conf_t	conf[];
extern const int	conf_elements;

extern const Prefix_t	prefix[];
extern const int	prefix_elements;

#endif
!
} > $tmp.2
case $debug in
-d7)	echo $command: $tmp.2 ${base}.h ;;
*)	cmp -s $tmp.2 ${base}.h 2>/dev/null || mv $tmp.2 ${base}.h ;;
esac

case $verbose in
1)	echo "$command: generate ${base}.c string table" >&2 ;;
esac
{
cat <<!
${head}
#include <sys/types.h>
#include <limits.h>
#include <unistd.h>$systeminfo$headers
${tail}
#include "${base}.h"

${generated}

/*
 * prefix strings -- the first few are indexed by Conf_t.standard
 */

const Prefix_t prefix[] =
{
!
for standard in $standards
do	case $shell in
	ksh)	len=${#standard} ;;
	*)	len=`echo ${standard} | wc -c`; len=`expr $len - 1` ;;
	esac
	echo "	\"${standard}\",	${len},	CONF_${standard},	-1,"
done
cat <<!
	"XX",		2,	CONF_POSIX,	CONF_nop,
	"CS",		2,	CONF_POSIX,	CONF_confstr,
	"PC",		2,	CONF_POSIX,	CONF_pathconf,
	"SC",		2,	CONF_POSIX,	CONF_sysconf,
	"SI",		2,	CONF_SVID,	CONF_sysinfo,
};

const int	prefix_elements = (int)sizeof(prefix) / (int)sizeof(prefix[0]);

/*
 * conf strings sorted in ascending order
 */

const Conf_t conf[] =
{
!
cat $tmp.t
cat <<!
};

const int	conf_elements = (int)sizeof(conf) / (int)sizeof(conf[0]);
!
} > $tmp.4
case $debug in
-d7)	echo $command: $tmp.4 ${base}.c ;;
*)	cmp -s $tmp.4 ${base}.c 2>/dev/null || mv $tmp.4 ${base}.c ;;
esac

# limits.h generation code

base=conflim
case $verbose in
1)	echo "$command: generate ${base}.h supplemental <limits.h> values" >&2 ;;
esac
{
cat <<!
${generated}

/*
 * supplemental <limits.h> values
 */

!
test -f $tmp.l && cat $tmp.l
} > $tmp.5
case $debug in
-d7)	echo $command: $tmp.5 ${base}.h ;;
*)	cmp -s $tmp.5 ${base}.h 2>/dev/null || mv $tmp.5 ${base}.h ;;
esac
exit 0
