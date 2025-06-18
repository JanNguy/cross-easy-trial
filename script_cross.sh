#!/usr/bin/env bash

PIDOF="$(which pidof)"
(test "${PIDOF}" && test -f "${PIDOF}") || brew install pidof

CO_PWD=~/Applications/CrossOver.app/Contents/MacOS
[ -d "${CO_PWD}" ] || CO_PWD=/Applications/CrossOver.app/Contents/MacOS
[ -d "${CO_PWD}" ] || { echo "❌ Impossible de localiser CrossOver.app. Abandon."; exit 1; }

cd "${CO_PWD}"

PROC_NAME='CrossOver'

pids=($(pgrep "${PROC_NAME}") $(pidof "${PROC_NAME}") $(ps -Ac | grep -m1 "${PROC_NAME}" | awk '{print $1}'))

if [ "${#pids[@]}" -gt 0 ]; then
  echo "🔄 Fermeture de CrossOver..."
  kill "${pids[@]}" > /dev/null 2>&1
  sleep 3
fi

if [ ! -f CrossOver.origin ]; then
  echo "💾 Sauvegarde de l'exécutable d'origine..."
  mv CrossOver CrossOver.origin
fi

echo "⏱️ Réinitialisation des dates de trial..."

DATETIME=$(date -u -v -3H '+%Y-%m-%dT%TZ')

plutil -replace FirstRunDate -date "${DATETIME}" ~/Library/Preferences/com.codeweavers.CrossOver.plist
plutil -replace SULastCheckTime -date "${DATETIME}" ~/Library/Preferences/com.codeweavers.CrossOver.plist

/usr/bin/osascript -e "display notification \"Trial modifié : date changée à ${DATETIME}\""

echo "🧹 Nettoyage des fichiers system.reg..."
for file in ~/Library/Application\ Support/CrossOver/Bottles/*/system.reg; do 
  sed -i '' -e "/^\\[Software\\\\\\\\CodeWeavers\\\\\\\\CrossOver\\\\\\\\cxoffice\\]/,+6d" "${file}";
done

echo "🧹 Suppression des fichiers .update-timestamp..."
for update_file in ~/Library/Application\ Support/CrossOver/Bottles/*/.update-timestamp; do 
  rm -f "${update_file}"
done

/usr/bin/osascript -e "display notification \"Bottles nettoyées : timestamps supprimés\""

echo "🛠️ Réécriture du binaire CrossOver..."
cat CrossOver.origin > CrossOver
chmod +x CrossOver

echo "🚀 Lancement de CrossOver.origin..."
"${PWD}/CrossOver.origin" >> /tmp/co_log.log 2>&1 &

