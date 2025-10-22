#!/usr/bin/env bash

PROC_NAME='CrossOver'
CO_PWD=~/Applications/CrossOver.app/Contents/MacOS
[ -d "${CO_PWD}" ] || CO_PWD=/Applications/CrossOver.app/Contents/MacOS

show_help() {
    cat << EOF
Usage: ${0##*/} [OPTIONS]

Script de gestion et réinitialisation de CrossOver

OPTIONS:
    -h, --help      Affiche cette aide
    -v, --version   Affiche la version

FONCTIONNALITÉS:
    • Ferme les processus CrossOver en cours
    • Sauvegarde l'exécutable original
    • Réinitialise les dates d'essai
    • Nettoie les fichiers des bouteilles
    • Relance l'application

AUTEUR:
    Développé par Jan Nguyen

EXEMPLES:
    ${0##*/}          # Exécute le script normalement
    ${0##*/} -h       # Affiche l'aide
EOF
}

show_version() {
    echo "CrossOver Manager v1.0"
    echo "Développé par Jan Nguyen"
    echo "https://github.com/jannguyen"
}

check_dependencies() {
    local pidof_cmd
    pidof_cmd=$(which pidof 2>/dev/null)

    if [[ ! -f "$pidof_cmd" ]]; then
        echo "📦 Installation de pidof..."
        brew install pidof || {
            echo "❌ Échec de l'installation de pidof"
            exit 1
        }
    fi
}

validate_crossover_path() {
    if [[ ! -d "${CO_PWD}" ]]; then
        echo "❌ Impossible de localiser CrossOver.app"
        exit 1
    fi
}

get_crossover_pids() {
    local pids=()

    pids+=($(pgrep "${PROC_NAME}" 2>/dev/null))
    pids+=($(pidof "${PROC_NAME}" 2>/dev/null))

    local ps_pid
    ps_pid=$(ps -Ac | grep -m1 "${PROC_NAME}" | awk '{print $1}' 2>/dev/null)
    [[ -n "$ps_pid" ]] && pids+=("$ps_pid")

    printf '%s\n' "${pids[@]}" | sort -nu
}

stop_crossover() {
    local pids=($(get_crossover_pids))

    if [[ ${#pids[@]} -gt 0 ]]; then
        echo "🔄 Fermeture de CrossOver..."
        kill "${pids[@]}" > /dev/null 2>&1
        sleep 3
    fi
}

backup_original() {
    if [[ ! -f CrossOver.origin ]]; then
        echo "💾 Sauvegarde de l'exécutable d'origine..."
        mv CrossOver CrossOver.origin || {
            echo "❌ Échec de la sauvegarde"
            exit 1
        }
    fi
}

reset_trial_dates() {
    local datetime
    datetime=$(date -u -v -3H '+%Y-%m-%dT%TZ')

    echo "⏱️ Réinitialisation des dates de trial..."

    plutil -replace FirstRunDate -date "${datetime}" \
        ~/Library/Preferences/com.codeweavers.CrossOver.plist
    plutil -replace SULastCheckTime -date "${datetime}" \
        ~/Library/Preferences/com.codeweavers.CrossOver.plist

    /usr/bin/osascript -e \
        "display notification \"Trial modifié : date changée à ${datetime}\""
}

clean_bottles() {
    echo "🧹 Nettoyage des fichiers system.reg..."

    for file in ~/Library/Application\ Support/CrossOver/Bottles/*/system.reg; do
        [[ -f "$file" ]] || continue
        sed -i '' -e "/^\\[Software\\\\\\\\CodeWeavers\\\\\\\\CrossOver\\\\\\\\cxoffice\\]/,+6d" "${file}"
    done

    echo "🧹 Suppression des fichiers .update-timestamp..."

    for update_file in ~/Library/Application\ Support/CrossOver/Bottles/*/.update-timestamp; do
        [[ -f "$update_file" ]] && rm -f "${update_file}"
    done

    /usr/bin/osascript -e "display notification \"Bottles nettoyées : timestamps supprimés\""
}

restore_binary() {
    echo "🛠️ Réécriture du binaire CrossOver..."
    cp CrossOver.origin CrossOver || {
        echo "❌ Échec de la restauration du binaire"
        exit 1
    }
    chmod +x CrossOver
}

start_crossover() {
    echo "🚀 Lancement de CrossOver..."
    "${PWD}/CrossOver.origin" >> /tmp/co_log.log 2>&1 &
}

main() {
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            show_version
            exit 0
            ;;
        "")
            ;;
        *)
            echo "❌ Option invalide: $1"
            echo "Utilisez -h pour voir l'aide"
            exit 1
            ;;
    esac

    echo "🛠️  CrossOver Manager - par Jan Nguyen"
    echo "======================================"

    check_dependencies
    validate_crossover_path

    cd "${CO_PWD}" || {
        echo "❌ Impossible d'accéder à ${CO_PWD}"
        exit 1
    }

    stop_crossover
    backup_original
    reset_trial_dates
    clean_bottles
    restore_binary
    start_crossover

    echo "✅ Opérations terminées avec succès"
}

main "$@"