#!/usr/bin/env bash

# todo: ernstchan
# curl -k -A "lulz" -F "task=post" -F "field4=kühler kommentar" -F "file=@/Users/blargh/Desktop/test.jpg" https://ernstchan.com/b/wakaba.pl

if [[ -z "$(type -P curl)" ]]; then
	echo "Dieses Skript benötigt cURL. Vergewissere dich, dass es installiert ist und im Suchpfad liegt."; exit 1
fi

ua="Krautchan-Hochladierer - http://git.io/KmtLlQ"
post_url="http://krautchan.net/post"
debug_file=${HOME}/debug.txt
pause=0
c_retry=3; c_delay=120; c_timeout=900; count=0; period_count=0; optional=0; combo=0
files_allowed=4; name_allowed=1; debug=0; interact=0; twist=0
bifs=${IFS}; id=; name=; isub=; icom=; start_time=0
delete_url="http://krautchan.net/delete"
#pwd=""
arr_kind=(-iname "*.gif" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.psd" -o -iname "*.mp3" -o -iname "*.ogg" -o -iname "*.rar" -o -iname "*.zip" -o -iname "*.torrent" -o -iname "*.swf")
arr_kind_red=(-iname "*.gif" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.psd")
kchelp="\n${0##*/} [-sordh] [-c 1-4] [-p <integer>] [-x <proxyhost[:port]>] [-k <komturcode>] Datei ...

Erstellt Fäden und pfostiert alle auf Krautchan erlaubten Dateien aus einem oder mehreren Verzeichnissen.
Alternativ lassen sich die zu pfostierenden Dateien als Skript-Argument angeben (Dateigröße und Art werden
dabei nicht berücksichtigt).
Während des Upload-Vorgangs lassen sich mittels ctrl-c Kommentare hinzufügen.
Getestet mit OS X, Debian Stale und Cygwin.

Wiezu:
 -s	Säge!
 -c n	Begrenzt die erlaubten Dateien pro Pfostierung auf n. Nützlich für Combos.
	Berücksichtige, dass z.B. 11.jpg vor 2.jpg einsortiert wird!
 -o	Optionale Abfragen (Name, Betreff und Kommentar) werden aktiviert.
 -r	Dateien werden in einer zufälligen Reihenfolge pfostiert.
 -p n	Zwischen den Pfostierungen wird eine Pause von n Sekunden eingelegt.
 -x n	HTTP-Proxy.
 -k n	Komturcode.
 -d	Debugoutput wird aktiviert (${debug_file}).
 -h	Diese Hilfe."

randomize() {
n=${#arr_files[@]}
while ((n)); do
	indices=("${!arr_files[@]}")		# kopiert den array-index in ein neues array
	i=${indices[RANDOM%n--]}			# rand modulo elementanzahl des arrays / post-decrement n
	echo "${arr_files[i]}"
	unset "arr_files[i]"
done
}

while getopts ":soc:rgp:x:k:dh" opt; do	# erster doppelpunkt: silent error; restliche doppelpunkte
	case "${opt}" in					# jeweils hinter dem optelementt welches einen fehler werfen soll
		s) 	sage=1 ;;
		c) 	[[ "${OPTARG}" != [1-4] ]] && echo -e "\nAch, Bernd! Nur die Ziffern 1 bis 4 ergeben Sinn ..." && exit 1
			combo=${OPTARG} ;;
		o) 	optional=1 ;;
		r)	twist=1 ;;
		g)	g=1 ;;
		p)	[[ "${OPTARG}" != *[!0-9]* ]] && pause="${OPTARG}" || exit 1 ;;
		x)	arr_proxy=(-x ${OPTARG}) ;;
		k)	arr_komtur=(-b desuchan.komturcode=${OPTARG}) ;;
		d)	debug=1 ;;
		h) 	echo -e "${kchelp}"; exit 0 ;;
		\?)	echo -e "\n \033[31m-${OPTARG} gibt es nicht!\033[m\n${kchelp}"; exit 1 ;;
		:)	echo -e "\n \033[31m-${OPTARG} benötigt ein Argument!\033[m\n${kchelp}"; exit 1 ;;
	esac
done

shift $((OPTIND-1))
[[ "${1}" == -- ]] && shift
arr_files=("${@}")

if [[ "${g}" -eq "1" ]]; then
	echo -e "\nBrett?"
	read -en 4 -p "> " board
	echo -e "\nFaden-ID? (z.B. 3025905)"
	read -ep "> " id
	while ((g)); do
		curl "${arr_proxy[@]}" "${arr_komtur[@]}" -s -A "${ua}" -F "board=${board}" -F "parent=${id}" -F "internal_t=01010101101" "${post_url}" > /dev/null
		## post_text_5492701
		output=$(curl "${arr_proxy[@]}" "${arr_komtur[@]}" -s -A "${ua}" http://krautchan.net/${board}/thread-${id}.html) 
		[[ $output =~ .*post_text_([0-9]*).* ]]
		dscheisse=${BASH_REMATCH[1]}
		curl "${arr_proxy[@]}" "${arr_komtur[@]}" -s -A "${ua}" -F "board=${board}" -F "parent=${id}" -F "post_${dscheisse}=delete" "${delete_url}" > /dev/null
		echo -e "\nNoch mal? (1/0)"
		read -en 1 -p "> " g
	done
	exit 0
fi

choose() {
echo -e "Wähle ein Brett aus\n (b,int,vip,a,c,co,d,e,f,fb,fit,jp,k,l,li,m,n,p,ph,sp,t,tv\n  v,w,we,wp,x,z,zp,ng,prog,trv,wk,h,s,kc,rfk)"
read -en 4 -p "> " board

case "${board}" in #NEGER, BITTE!
	b|int|trv|vip)											max_file_size=10M; name_allowed=0 ;;
	a|jp)													max_file_size=9M ;;
	k)														max_file_size=10M ;; #max_post_size=15
	l|m)													max_file_size=20M ;; #max_post_size=40
	c|co|d|e|f|fb|fit|li|n|p|ph|ng|prog|sp|t|tv|v|w|we|wk|x)	max_file_size=6M ;;
	rfk)													max_file_size=5M ;;
	kc)														max_file_size=3M ;;
	h|s|wp|z|zp)											max_file_size=6M; arr_kind=(${arr_kind_red[@]});;
	*)														echo -e "\nDepp.\n"; choose ;;
esac
}

clear

#cat <<'EOF'
#
#
#
#   __ __              __      __
#  / //_/______ ___ __/ /_____/ /  ___ ____  ____
# / ,< / __/ _ `/ // / __/ __/ _ \/ _ `/ _ \/___/
#/_/|_/_/  \_,_/\_,_/\__/\__/_//_/\_,_/_//_/
#                 __ __         __   __        ___                
#                / // /__  ____/ /  / /__ ____/ (_)__ _______ ____
#               / _  / _ \/ __/ _ \/ / _ `/ _  / / -_) __/ -_) __/
#              /_//_/\___/\__/_//_/_/\_,_/\_,_/_/\__/_/  \__/_/
#
#
#
#EOF

cat <<'EOF'


[38;5;39m [0m[38;5;39m [0m[38;5;44m [0m[38;5;44m_[0m[38;5;44m_[0m[38;5;44m [0m[38;5;49m_[0m[38;5;49m_[0m[38;5;49m [0m[38;5;48m [0m[38;5;48m [0m[38;5;48m [0m[38;5;84m [0m[38;5;83m [0m[38;5;83m [0m[38;5;83m [0m[38;5;119m [0m[38;5;118m [0m[38;5;118m [0m[38;5;118m [0m[38;5;154m [0m[38;5;154m [0m[38;5;154m_[0m[38;5;184m_[0m[38;5;184m [0m[38;5;184m [0m[38;5;184m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;208m_[0m[38;5;208m_[0m
[38;5;39m [0m[38;5;44m [0m[38;5;44m/[0m[38;5;44m [0m[38;5;44m/[0m[38;5;49m/[0m[38;5;49m_[0m[38;5;49m/[0m[38;5;48m_[0m[38;5;48m_[0m[38;5;48m_[0m[38;5;84m_[0m[38;5;83m_[0m[38;5;83m_[0m[38;5;83m [0m[38;5;119m_[0m[38;5;118m_[0m[38;5;118m_[0m[38;5;118m [0m[38;5;154m_[0m[38;5;154m_[0m[38;5;154m/[0m[38;5;184m [0m[38;5;184m/[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;208m/[0m[38;5;208m [0m[38;5;208m/[0m[38;5;209m [0m[38;5;203m [0m[38;5;203m_[0m[38;5;203m_[0m[38;5;204m_[0m[38;5;198m [0m[38;5;198m_[0m[38;5;198m_[0m[38;5;199m_[0m[38;5;199m_[0m[38;5;199m [0m[38;5;164m [0m[38;5;164m_[0m[38;5;164m_[0m[38;5;164m_[0m[38;5;129m_[0m
[38;5;44m [0m[38;5;44m/[0m[38;5;44m [0m[38;5;44m,[0m[38;5;49m<[0m[38;5;49m [0m[38;5;49m/[0m[38;5;48m [0m[38;5;48m_[0m[38;5;48m_[0m[38;5;84m/[0m[38;5;83m [0m[38;5;83m_[0m[38;5;83m [0m[38;5;119m`[0m[38;5;118m/[0m[38;5;118m [0m[38;5;118m/[0m[38;5;154m/[0m[38;5;154m [0m[38;5;154m/[0m[38;5;184m [0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m/[0m[38;5;214m [0m[38;5;214m_[0m[38;5;214m_[0m[38;5;208m/[0m[38;5;208m [0m[38;5;208m_[0m[38;5;209m [0m[38;5;203m\[0m[38;5;203m/[0m[38;5;203m [0m[38;5;204m_[0m[38;5;198m [0m[38;5;198m`[0m[38;5;198m/[0m[38;5;199m [0m[38;5;199m_[0m[38;5;199m [0m[38;5;164m\[0m[38;5;164m/[0m[38;5;164m_[0m[38;5;164m_[0m[38;5;129m_[0m[38;5;129m/[0m
[38;5;44m/[0m[38;5;44m_[0m[38;5;44m/[0m[38;5;49m|[0m[38;5;49m_[0m[38;5;49m/[0m[38;5;48m_[0m[38;5;48m/[0m[38;5;48m [0m[38;5;84m [0m[38;5;83m\[0m[38;5;83m_[0m[38;5;83m,[0m[38;5;119m_[0m[38;5;118m/[0m[38;5;118m\[0m[38;5;118m_[0m[38;5;154m,[0m[38;5;154m_[0m[38;5;154m/[0m[38;5;184m\[0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m/[0m[38;5;214m\[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;208m/[0m[38;5;208m_[0m[38;5;208m/[0m[38;5;209m/[0m[38;5;203m_[0m[38;5;203m/[0m[38;5;203m\[0m[38;5;204m_[0m[38;5;198m,[0m[38;5;198m_[0m[38;5;198m/[0m[38;5;199m_[0m[38;5;199m/[0m[38;5;199m/[0m[38;5;164m_[0m[38;5;164m/[0m
[38;5;44m [0m[38;5;44m [0m[38;5;49m [0m[38;5;49m [0m[38;5;49m [0m[38;5;48m [0m[38;5;48m [0m[38;5;48m [0m[38;5;84m [0m[38;5;83m [0m[38;5;83m [0m[38;5;83m [0m[38;5;119m [0m[38;5;118m [0m[38;5;118m [0m[38;5;118m [0m[38;5;154m [0m[38;5;154m_[0m[38;5;154m_[0m[38;5;184m [0m[38;5;184m_[0m[38;5;184m_[0m[38;5;184m [0m[38;5;214m [0m[38;5;214m [0m[38;5;214m [0m[38;5;208m [0m[38;5;208m [0m[38;5;208m [0m[38;5;209m [0m[38;5;203m [0m[38;5;203m_[0m[38;5;203m_[0m[38;5;204m [0m[38;5;198m [0m[38;5;198m [0m[38;5;198m_[0m[38;5;199m_[0m[38;5;199m [0m[38;5;199m [0m[38;5;164m [0m[38;5;164m [0m[38;5;164m [0m[38;5;164m [0m[38;5;129m [0m[38;5;129m [0m[38;5;129m_[0m[38;5;93m_[0m[38;5;93m_[0m[38;5;93m [0m[38;5;99m [0m[38;5;63m [0m[38;5;63m [0m[38;5;63m [0m[38;5;69m [0m[38;5;33m [0m[38;5;33m [0m[38;5;33m [0m[38;5;39m [0m[38;5;39m [0m[38;5;39m [0m[38;5;44m [0m[38;5;44m [0m[38;5;44m [0m[38;5;44m [0m
[38;5;44m [0m[38;5;49m [0m[38;5;49m [0m[38;5;49m [0m[38;5;48m [0m[38;5;48m [0m[38;5;48m [0m[38;5;84m [0m[38;5;83m [0m[38;5;83m [0m[38;5;83m [0m[38;5;119m [0m[38;5;118m [0m[38;5;118m [0m[38;5;118m [0m[38;5;154m [0m[38;5;154m/[0m[38;5;154m [0m[38;5;184m/[0m[38;5;184m/[0m[38;5;184m [0m[38;5;184m/[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;214m [0m[38;5;208m [0m[38;5;208m_[0m[38;5;208m_[0m[38;5;209m_[0m[38;5;203m_[0m[38;5;203m/[0m[38;5;203m [0m[38;5;204m/[0m[38;5;198m [0m[38;5;198m [0m[38;5;198m/[0m[38;5;199m [0m[38;5;199m/[0m[38;5;199m_[0m[38;5;164m_[0m[38;5;164m [0m[38;5;164m_[0m[38;5;164m_[0m[38;5;129m_[0m[38;5;129m_[0m[38;5;129m/[0m[38;5;93m [0m[38;5;93m([0m[38;5;93m_[0m[38;5;99m)[0m[38;5;63m_[0m[38;5;63m_[0m[38;5;63m [0m[38;5;69m_[0m[38;5;33m_[0m[38;5;33m_[0m[38;5;33m_[0m[38;5;39m_[0m[38;5;39m_[0m[38;5;39m_[0m[38;5;44m [0m[38;5;44m_[0m[38;5;44m_[0m[38;5;44m_[0m[38;5;49m_[0m
[38;5;49m [0m[38;5;49m [0m[38;5;49m [0m[38;5;48m [0m[38;5;48m [0m[38;5;48m [0m[38;5;84m [0m[38;5;83m [0m[38;5;83m [0m[38;5;83m [0m[38;5;119m [0m[38;5;118m [0m[38;5;118m [0m[38;5;118m [0m[38;5;154m [0m[38;5;154m/[0m[38;5;154m [0m[38;5;184m_[0m[38;5;184m [0m[38;5;184m [0m[38;5;184m/[0m[38;5;214m [0m[38;5;214m_[0m[38;5;214m [0m[38;5;208m\[0m[38;5;208m/[0m[38;5;208m [0m[38;5;209m_[0m[38;5;203m_[0m[38;5;203m/[0m[38;5;203m [0m[38;5;204m_[0m[38;5;198m [0m[38;5;198m\[0m[38;5;198m/[0m[38;5;199m [0m[38;5;199m/[0m[38;5;199m [0m[38;5;164m_[0m[38;5;164m [0m[38;5;164m`[0m[38;5;164m/[0m[38;5;129m [0m[38;5;129m_[0m[38;5;129m [0m[38;5;93m [0m[38;5;93m/[0m[38;5;93m [0m[38;5;99m/[0m[38;5;63m [0m[38;5;63m-[0m[38;5;63m_[0m[38;5;69m)[0m[38;5;33m [0m[38;5;33m_[0m[38;5;33m_[0m[38;5;39m/[0m[38;5;39m [0m[38;5;39m-[0m[38;5;44m_[0m[38;5;44m)[0m[38;5;44m [0m[38;5;44m_[0m[38;5;49m_[0m[38;5;49m/[0m
[38;5;49m [0m[38;5;49m [0m[38;5;48m [0m[38;5;48m [0m[38;5;48m [0m[38;5;84m [0m[38;5;83m [0m[38;5;83m [0m[38;5;83m [0m[38;5;119m [0m[38;5;118m [0m[38;5;118m [0m[38;5;118m [0m[38;5;154m [0m[38;5;154m/[0m[38;5;154m_[0m[38;5;184m/[0m[38;5;184m/[0m[38;5;184m_[0m[38;5;184m/[0m[38;5;214m\[0m[38;5;214m_[0m[38;5;214m_[0m[38;5;208m_[0m[38;5;208m/[0m[38;5;208m\[0m[38;5;209m_[0m[38;5;203m_[0m[38;5;203m/[0m[38;5;203m_[0m[38;5;204m/[0m[38;5;198m/[0m[38;5;198m_[0m[38;5;198m/[0m[38;5;199m_[0m[38;5;199m/[0m[38;5;199m\[0m[38;5;164m_[0m[38;5;164m,[0m[38;5;164m_[0m[38;5;164m/[0m[38;5;129m\[0m[38;5;129m_[0m[38;5;129m,[0m[38;5;93m_[0m[38;5;93m/[0m[38;5;93m_[0m[38;5;99m/[0m[38;5;63m\[0m[38;5;63m_[0m[38;5;63m_[0m[38;5;69m/[0m[38;5;33m_[0m[38;5;33m/[0m[38;5;33m [0m[38;5;39m [0m[38;5;39m\[0m[38;5;39m_[0m[38;5;44m_[0m[38;5;44m/[0m[38;5;44m_[0m[38;5;44m/[0m


EOF

choose

echo -e "\nMaximal erlaubte Dateianzahl:\t${files_allowed}\nMaximal erlaubte Dateigröße:\t${max_file_size}B"

if [[ "${combo}" -gt "${files_allowed}" ]]; then
	echo -e "\nEine ${combo}er-Combo ist nicht möglich, da auf /${board}/ nur ${files_allowed} Dateien pro Pfostierung erlaubt sind."
	exit 1
elif [[ "${combo}" -ne "0" ]]; then
	files_allowed=${combo}
fi

echo -e "\nFaden-ID\n (z.B. 3025905 - leer lassen um einen neuen Faden zu erstellen)"
read -ep "> " id

if [[ -z "${arr_files}" ]]; then
	echo -e "\nVerzeichniss(e) auswählen. Leerzeichen müssen escaped werden.\n (z.B.: /Users/bernd/penisbilder /home/bernadette/als\ ob)"
	read -ep "> " -a arr_dir
	
	IFS=$'\n' # erlaubt leerzeichen in dateipfaden und dateinamen, trennt den find/randomize output in einzelne elemente
	
	for dir in "${arr_dir[@]}"; do
		for files in $(find "${dir}" -type f -size -${max_file_size} \( ${arr_kind[@]} \) ); do
			arr_files+=("${files}")
		done
	done
	
	IFS=${bifs}
fi

echo -e "\n${#arr_files[@]} Dateien gefunden."

if [[ "${twist}" -eq "1" ]]; then
	echo "Zufällige Reihenfolge wird erstellt …"
	IFS=$'\n'
	arr_files=( $(randomize) )
	IFS=${bifs}
fi

if [[ "${optional}" -eq "1" ]]; then
	if [[ "${name_allowed}" -eq "1" ]]; then
		echo -e "\nName"
		read -ep "> " name
	fi
	echo -e "\nBetreff\n (Wird nur ein mal pfostiert)"
	read -ep "> " isub
	echo -e "\nKommentar\n (Wird nur ein mal pfostiert)"
	read -ep "> " icom
elif [[ -z "${id}" ]] && [[ -z "${icom}" ]]; then
	while [[ -z "${icom}" ]]; do
		echo -e "\nKommentar\n (Ist nötig, weil ein neuer Faden erstellt wird. Wird nur ein mal pfostiert.)"
		read -ep "> " icom
	done
fi

arr_files+=(END)

echo

trap 'interact=1' 2

for file in "${arr_files[@]}"; do
	((count += 1))
	if [[ "${file}" != "END" ]]; then
		if [[ "${files_allowed}" -eq "1" ]]; then
			arr_curl+=(-F file_0=@${file})
		elif [[ "${count}" -eq "1" ]]; then
			arr_curl+=(-F file_0=@${file})
			continue
		elif [[ "${files_allowed}" -eq "2" ]]; then
			arr_curl+=(-F file_1=@${file})
		elif [[ "${count}" -eq "2" ]]; then
			arr_curl+=(-F file_1=@${file})
			continue
		elif [[ "${files_allowed}" -eq "3" ]]; then
			arr_curl+=(-F file_2=@${file})
		elif [[ "${count}" -eq "3" ]]; then
			arr_curl+=(-F file_2=@${file})
			continue
		elif [[ "${count}" -eq "4" ]]; then
			arr_curl+=(-F file_3=@${file})
		fi
	# verhindert curl-fehler im falle von ${files_allowed}|${arr_files[@]}
	elif [[ "${file}" = "END" ]] && [[ "${count}" -eq "1" ]]; then
		exit 0
	fi
	
	if [[ "${interact}" -eq "1" ]]; then
		echo -e "\nSkript wirklich [b]eenden oder [K]ommentar hinzufügen und fortsetzen?"
		read -en 1 interact_ans
		case "${interact_ans}" in
			b|B)	exit 0 ;;
			k|K)	read -ep "Kommentar: " icom; interact=0 ;;
			*)		exit 1 ;;
		esac
	fi
	
	output=$(trap '' 2; curl "${arr_proxy[@]}" "${arr_komtur[@]}" --retry "${c_retry}" --retry-delay "${c_delay}" --max-time "${c_timeout}" -# -A "${ua}" -F "sage=${sage}" -F "board=${board}" -F "parent=${id}" -F "forward=thread" -F "internal_n=${name}" -F "internal_s=${isub}" -F "internal_t=${icom}" "${arr_curl[@]}" "${post_url}")
	
	((period_count += 1))
	
	if [[ "${period_count}" -gt "3" ]]; then
		((start_diff = $(date +%s) - start_time))
		if [[ "${start_diff}" -lt "60" ]]; then
			echo "Pause für $((60 - start_diff)) Sekunden um das Pfostenlimit von 4 Pfosten pro Minute nicht zu überschreiten."
			sleep $((60 - start_diff))
			period_count=0
			start_time=0
		fi
	fi
	
	[[ "${start_time}" -eq "0" ]] && [[ "${period_count}" -ge "1" ]] && start_time=$(date +%s)
	
	[[ ${output} =~ .*banned.* ]] && echo "Sie, mein Herr, sind banniert! Glückwunsch! (http://krautchan.net/banned)" && exit 1
	
	[[ ${output} =~ .*Verification\ code\ wrong.* ]] || [[ ${output} =~ .*Verifizierungscode\ falsch\..* ]] && echo "Captchas sind aktiv ;_;" && exit 1
	
	[[ ${output} =~ .*Posts\ in\ 60\ Sekunden.* ]] && echo "Mehr als 4 Pfosten pro Minute sind nicht erlaubt. Verworfen."
	
	[[ "${debug}" -eq "1" ]] && echo -ne "${arr_curl[@]}\n\n${icom}\n\n${id}\n\n${output}\n\n##\n##\n\n" >> ${debug_file}
	
	if [[ -z "${id}" ]]; then
		[[ $output =~ .*thread-([0-9]*)\.html.* ]]
		id=${BASH_REMATCH[1]}
		echo "Neuen Faden erstellt: http://krautchan.net/${board}/thread-${id}.html"
	fi
	
	[[ "${pause}" -gt "0" ]] && echo "Pause: ${pause} Sekunden" && sleep ${pause}
	
	unset arr_curl
	count=0; isub=; icom=
done

exit 0
