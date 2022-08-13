#!/usr/bin/env bash

#########################
# radarr_import_subs.sh
# Radarr script to import subtitles from subdirectories
#
# https://github.com/ftc2/radarr_import_subs.sh
# (C) 2022 ftc2

#########################
# Installation

# 1) put this script somewhere that radarr can access
# 2) make it executable
#      chmod +x /path/to/radarr_import_subs.sh
# 3) add your radarr API info in the Setup section of this script to trigger rescan after import
#      RADARR_URL, RADARR_API_KEY
# 4) add this script to radarr as a custom connection
#      Radarr WebUI > Settings > Connect > Add (+) > Custom Script
#        Name: Subdirectory Subtitle Importer
#        Triggers: On Import, On Upgrade
#        Path: /path/to/radarr_import_subs.sh

#########################
# Setup

RADARR_URL='' # including port (and base path if applicable)
  # no trailing slash!
  # example with base path: 'http://192.168.33.112:7878/basepath'
RADARR_API_KEY='' # Radarr WebUI > Settings > General > Security
RELEASE_GRPS=('RARBG' 'VXT' 'YTS' 'YTS.MX') # only process these groups' releases
SUB_DIRS=('Subs' 'Subtitles') # paths to search for subtitles
SUB_EXTS='srt\|ass' # subtitle file extensions separated by \|
#SUB_EN_REGEX="([0-9]{1,2}\_English.*|.*eng).*\.\(${SUB_EXTS}\)$" # regex used to find subtitles (in this POS regex variant, you have to escape ())
#SUB_FR_REGEX="([0-9]{1,2}\_French.*|.*fre).*\.\(${SUB_EXTS}\)$" # regex used to find subtitles (in this POS regex variant, you have to escape ())

# Any *.srt or *.ass
SUB_DEFAULT_REGEX=".*\.\(${SUB_EXTS}\)$" # regex used to find subtitles (in this POS regex variant, you have to escape ())
# Format 2_English.srt
SUB_EN_REGEX=".*[0-9][0-9]?\_English.*\.\(${SUB_EXTS}\)$" # regex used to find subtitles (in this POS regex variant, you have to escape ())
SUB_FR_REGEX=".*[0-9][0-9]?\_French\.\(${SUB_EXTS}\)$" # regex used to find subtitles (in this POS regex variant, you have to escape ())
# Format subtitle.eng.srt
SUB_EN_2_REGEX=".*\(eng\|English\)\.\(${SUB_EXTS}\)$" # regex used to find subtitles (in this POS regex variant, you have to escape ())
SUB_FR_2_REGEX=".*\(fre\|French\)\.\(${SUB_EXTS}\)$" # regex used to find subtitles (in this POS regex variant, you have to escape ())

SUB_EN_LANG='en' # this just gets added to final subtitle filenames
SUB_FR_LANG='fr' # this just gets added to final subtitle filenames
LOGGING=''
  #      '': standard logging
  # 'debug': log all messages to stderr to make them visible as Info in radarr logs
  # 'trace': log more info (print environment)

#########################
# Logging

log() {
  # stderr -> radarr Error
  echo "$1" >&2
}
dlog() {
  if [[ "$LOGGING" == 'debug' || "$LOGGING" == 'trace' ]]; then
    log "Debug: ${1}"
  else
    log "$1"
  fi
}
tlog() {
  [[ "$LOGGING" == 'trace' ]] && log "Trace: ${1}"
}

#########################
# Test/Debug

# https://wiki.servarr.com/radarr/custom-scripts#on-importon-upgrade
# first, print out the shell environment from an actual movie import (or set LOGGING=trace):
# log "$(printenv)"
# then look in the logs and copy stuff from there below to simulate a movie
# radarr_eventtype='Test' # uncomment to debug from shell
if [[ "$radarr_eventtype" == 'Test' ]]; then
  # this script needs the following stuff defined for testing:
  radarr_eventtype='Download'
  radarr_moviefile_releasegroup='YTS.MX'
  radarr_moviefile_sourcefolder='.'
  radarr_moviefile_sourcepath=''
  radarr_movie_path=''
  radarr_moviefile_path='/workspace/radarr_import_subs.sh/title_of_movie.mp4'
  radarr_moviefile_relativepath=''
  radarr_movie_id='46'
  radarr_movie_title='The Sea Beast'
  radarr_movie_year=''
fi
# after that, you can just hit the Test button on the Edit Connection dialog in radarr
# alternatively, you can run this script from a shell by setting the event type to Test above

#########################
# Main Script

# check event type
[[ "$radarr_eventtype" != 'Download' ]] && exit 0

# check release group
printf '%s\0' "${RELEASE_GRPS[@]}" | grep -F -x -- "$radarr_moviefile_releasegroup" >/dev/null || exit 0

multiAnalyseDirectory() {
  # path exists
  cd "$sub_dir" # `find` searches entire path, so `cd` to get relative path instead!
  dlog "Analyse for english subtitles"
  local nb_subtitle_found=1
  analyseDirectory $SUB_EN_REGEX $SUB_EN_LANG
  analyseDirectory $SUB_EN_2_REGEX $SUB_EN_LANG
  dlog "Analyse for french subtitles"
  local nb_subtitle_found=0
  analyseDirectory $SUB_FR_REGEX $SUB_FR_LANG
  analyseDirectory $SUB_FR_2_REGEX $SUB_FR_LANG
  # back to previous directory
  cd ..
}

analyseDirectory() {
  sub_regex="$1"
  sub_lang="$2"
  # switch commment line for alpine/ubuntu
  num_subs=$(find . -maxdepth 1 -type f -regex "${sub_regex}" | wc -l)
  # num_subs=$(find . -maxdepth 1 -type f -iregex "${sub_regex}" -printf '.' | wc -c)
  dlog "Found ${num_subs} matching subtitle(s) with ${sub_regex}"
  if [[ "$num_subs" -ge 1 ]]; then
    sub_track=$((nb_subtitle_found))
    # switch commment line for alpine/ubuntu
    find . -maxdepth 1 -type f -regex "${sub_regex}" -print0 |
    # find . -maxdepth 1 -type f -iregex "${sub_regex}" -print0 |
    while read -r -d '' sub_file; do      
      dlog "Current subtitle: ${sub_file}"
      sub_ext="${sub_file##*.}"
      if [[ "$sub_track" -gt 0 ]]; then
        log "Copying first subtitle: ${rel_sub_dir}/${sub_file##*/} --> ${sub_path_prefix}.${sub_lang}.${sub_track}.${sub_ext}"
        cp "${sub_file}" "${sub_path_prefix}.${sub_lang}.${sub_track}.${sub_ext}"
      else
        log "Copying subtitle: ${rel_sub_dir}/${sub_file##*/} --> ${sub_path_prefix}.${sub_lang}.${sub_ext}"
        cp "${sub_file}" "${sub_path_prefix}.${sub_lang}.${sub_ext}"
      fi
      sub_track=$((sub_track+1))
    done
    nb_subtitle_found=$((num_subs+nb_subtitle_found))
  else
    dlog "No subtitles found in ${sub_dir}" 
  fi
}

radarr_rescan() {
  local api_url="${RADARR_URL}/api/v3/command?apikey=${RADARR_API_KEY}"
  log "Triggering radarr rescan of ${radarr_movie_title} (${radarr_movie_year})..."
  local response=$(curl \
    --silent \
    -X POST \
    -d "{\"name\": \"RescanMovie\", \"movieId\": ${radarr_movie_id}}" \
    -H 'Content-Type: application/json' \
    "$api_url")
  tlog "$response"
  if command -v jq; then
    # `jq` is installed
    local status=$(echo "$response" | jq '.body | .completionMessage')
    tlog "Rescan API request status: ${status}"
    [[ "$status" == '"Completed"' ]] || log 'ERROR: Failed to trigger rescan in radarr. Check script API settings.'
  fi
}

dlog '----------Subdirectory Subtitle Importer----------'
tlog "$(printenv)"

# full target path for sub files (without file extension)
sub_path_prefix="${radarr_moviefile_path%.*}"

dlog "Analyse root subtitles is set for default english"
sub_dir="root level"
analyseDirectory $SUB_DEFAULT_REGEX $SUB_EN_LANG

for rel_sub_dir in "${SUB_DIRS[@]}"; do
  dlog "Current subtitle dir: ${rel_sub_dir}"
  sub_dir="${radarr_moviefile_sourcefolder}/${rel_sub_dir}"
  if [[ -d "$sub_dir" ]]; then
    multiAnalyseDirectory
  fi
done

radarr_rescan
