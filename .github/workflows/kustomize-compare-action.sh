#!/bin/bash

################## Defaults
KUSTOMIZE_BUILD_TEMP=kustomize_build_temp
BRANCH_NAME_TO_COMPARE="origin/master"

##### validate input args
echo -ne "┌─── kustomize-compare-action\r"
if [ -n "$1" ]; then KUSTOMIZATION_DIR_LOCATION="$1"; else echo -ne '\n'; echo "┝ ERROR Please specify directory path to overlay kustomization.yaml file";echo "└───  "; exit 1; fi
if [[ -f "$KUSTOMIZATION_DIR_LOCATION" ]] || [ ! -z "$(cd "${KUSTOMIZATION_DIR_LOCATION}" 2>&1)" ]; then  echo "┝ ERROR the kustomization directory path $(pwd)/$KUSTOMIZATION_DIR_LOCATION does not exist"; exit 1; fi
echo "┌─── kustomize-compare-action ${KUSTOMIZATION_DIR_LOCATION}";

cd "${KUSTOMIZATION_DIR_LOCATION}" || exit

######## get original code at branch off
DIR_TOP_LEVEL=$(git rev-parse --show-toplevel)
KUSTOMIZATION_DIR_RELATIVE_PATH="$(pwd | sed s+"${DIR_TOP_LEVEL}"/++g)"

CURRENT_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
BRANCHED_OFF_HASH=$(git merge-base "${CURRENT_BRANCH_NAME}" "${BRANCH_NAME_TO_COMPARE}")

echo "┝ Comparing kustomize build ${KUSTOMIZATION_DIR_RELATIVE_PATH}/kustomization.yaml"
echo "┝ Branch ${CURRENT_BRANCH_NAME} with code from ${BRANCH_NAME_TO_COMPARE} branched off commit ${BRANCHED_OFF_HASH}"
changes_detected=false






######## build kustomize for current changes and split in separate object for comparison
echo -ne "┝ ↻ Building kustomize for current code in ${KUSTOMIZATION_DIR_RELATIVE_PATH}/${KUSTOMIZE_BUILD_TEMP}\r"
mkdir -p "${KUSTOMIZE_BUILD_TEMP}"
kustomize_build_new=$(kustomize build . 2>&1 > "${KUSTOMIZE_BUILD_TEMP}"/kustomize-new.yaml)
if [ ! -z "$kustomize_build_new" ]; then
  echo -ne "┝ ✗ Building kustomize for current code in ${KUSTOMIZATION_DIR_RELATIVE_PATH}/${KUSTOMIZE_BUILD_TEMP}\r"
  echo -ne '\n'
  while IFS= read -r line ; do echo "  ├ $line"; done <<< "$kustomize_build_new"
  if [ -d "${KUSTOMIZE_BUILD_TEMP}" ]; then rm -rf "${KUSTOMIZE_BUILD_TEMP}"; fi
  echo "└───  "
  exit 1
else
  echo -ne "┝ ✓️ Building kustomize for current code in ${KUSTOMIZATION_DIR_RELATIVE_PATH}/${KUSTOMIZE_BUILD_TEMP}\r"
  echo -ne '\n'
  cd "${DIR_TOP_LEVEL}/${KUSTOMIZATION_DIR_RELATIVE_PATH}/${KUSTOMIZE_BUILD_TEMP}"
  cat kustomize-new.yaml | csplit - -f 'new.' -b '%03d.yaml' -k /^---$/ '{*}' > /dev/null
fi





# get all files from old commits to build kustomize old state
echo -ne "┝ ↻ Get previous code version\r"
cd "${DIR_TOP_LEVEL}/${KUSTOMIZATION_DIR_RELATIVE_PATH}/${KUSTOMIZE_BUILD_TEMP}"
detached_folder="${BRANCH_NAME_TO_COMPARE}-detached"
if [ -d "$detached_folder" ]; then rm -Rf $detached_folder; fi
prune_worktree=$(git worktree prune)
detaching_git_worktree=$(git worktree add ${detached_folder} --checkout --detach "${BRANCH_NAME_TO_COMPARE}") || exit 1
#while IFS= read -r line ; do echo -ne "  + $line\r"; done <<< "$detaching_git_worktree"
cat kustomize-new.yaml | csplit - -f 'new.' -b '%03d.yaml' -k /^---$/ '{*}' > /dev/null

echo -ne "┝ ✓️ Get previous code version\r"
echo -ne '\n'
cd "${detached_folder}"


# check if same directory exists in other branch
echo -ne "┝ ↻ Is there something to compare\r"
is_new_deployment=false
if [[ -f "$KUSTOMIZATION_DIR_RELATIVE_PATH" ]] || [ ! -z "$(cd "${KUSTOMIZATION_DIR_RELATIVE_PATH}" 2>&1)" ]; then
  echo -ne "┝ ✗  Nothing to compare.New definitions \r"
  echo -ne '\n'
  if [ -d "${KUSTOMIZE_BUILD_TEMP}" ]; then rm -Rf "${KUSTOMIZE_BUILD_TEMP}"; fi
  is_new_deployment=true
  changes_detected=true
fi


################## build kustomize old state only if there is something to compare
if [ "$is_new_deployment" = false ]; then
  echo -ne "┝ ✓ Is there something to compare\r"
  cd "${KUSTOMIZATION_DIR_RELATIVE_PATH}"
  checkout_branched_off_hash=$(git checkout "${BRANCHED_OFF_HASH}" 2>&1) || exit 1

  # build kustomize old state
  kustomize_build_old=$(kustomize build . 2>&1 > "${DIR_TOP_LEVEL}/${KUSTOMIZATION_DIR_RELATIVE_PATH}/"${KUSTOMIZE_BUILD_TEMP}"/kustomize-old.yaml")
  if [ ! -z "$kustomize_build_old" ]; then
    echo "  + ERROR kustomize build failed for $BRANCH_NAME_TO_COMPARE"
    while IFS= read -r line ; do echo "  + $line"; done <<< "$kustomize_build_old"
    cd "${DIR_TOP_LEVEL}/${KUSTOMIZATION_DIR_RELATIVE_PATH}"
    if [ -d "${KUSTOMIZE_BUILD_TEMP}" ]; then rm -Rf "${KUSTOMIZE_BUILD_TEMP}"; fi
    exit 1
  fi

  cd "${DIR_TOP_LEVEL}/${KUSTOMIZATION_DIR_RELATIVE_PATH}/${KUSTOMIZE_BUILD_TEMP}"
  git worktree prune
  if [ -d "$detached_folder" ]; then rm -Rf $detached_folder; fi

  cat kustomize-old.yaml | csplit - -f 'old.' -b '%03d.yaml' -k /^---$/ '{*}' > /dev/null
fi



echo -ne "┝ ↻ Processing files\r"
cd "${DIR_TOP_LEVEL}/${KUSTOMIZATION_DIR_RELATIVE_PATH}/${KUSTOMIZE_BUILD_TEMP}"
generated_files=$(ls | grep -E ".*[0-9]+\.yaml$")
file_prefix_to_diff=""

for file in $generated_files
do
  version="new"
  if [[ $file == *"old"* ]]; then version="old"; fi
  apiVersion=$(yq r $file apiVersion | sed "s+/+"W"+g")
  kind=$(yq r $file kind)
  name=$(yq r $file metadata.name)
  ns=$(yq r $file metadata.namespace)

  if [ -z "$ns" ]; then
    if [ "$kind" == "Namespace" ]; then
      ns="$name"
    else
      ns="default"
    fi
  fi
  new_file_name="${ns}_${kind}_${name}_${apiVersion}"
  if [[ $file_prefix_to_diff != *"$new_file_name"* ]]; then file_prefix_to_diff="${file_prefix_to_diff} $new_file_name"; fi
  mv "$file" "${new_file_name}_${version}.yaml"
done
echo -ne "┝ ✓️ Processing files\r"
echo -ne '\n'

function print_object_header {
  local res=""
  IFS='_' read -ra ADDR <<< "$1"
  res="${res}| apiVersion: $( echo ${ADDR[3]} | sed s+W+/+g)\n"
  res="${res}| kind: ${ADDR[1]}\n"
  res="${res}| metadata:\n"
  res="${res}|   name: ${ADDR[2]}\n"
  res="${res}|   namespace: ${ADDR[0]}\n"
  printf "$res"
}

#### scan for changes
changes_message="\n"

for file_prefix in ${file_prefix_to_diff}
do
  [ ! -f "${file_prefix}_old.yaml" ] && changes_detected=true && changes_message="${changes_message}\n++++++++  NEW OBJECT\n$(print_object_header "$file_prefix")\n|____________\n\n"
  [ ! -f "${file_prefix}_new.yaml" ] && changes_detected=true && changes_message="${changes_message}\n--------  DELETED OBJECT\n$(print_object_header "$file_prefix")\n|____________\n\n"
  if [ -f "${file_prefix}_old.yaml" ] && [ -f "${file_prefix}_new.yaml" ]; then
    diff_result=$(git diff -U0 --no-prefix --no-index "${file_prefix}_old.yaml" "${file_prefix}_new.yaml" | tail -n +5)
    if [ ! -z "$diff_result" ]; then
      changes_detected=true
      changes_message="${changes_message}***** UPDATED OBJECT \n$(print_object_header "$file_prefix")\n+------------------\n"
      while IFS= read -r line ; do changes_message="${changes_message}$line\n" ; done <<< "$diff_result"
      changes_message="${changes_message}-------------------\n"
    fi
  fi
done
if [ "$changes_detected" = false ] ; then
  echo "┝ ✗  No changes detected for ${KUSTOMIZATION_DIR_RELATIVE_PATH}/kustomization.yaml"
else
  printf  "$changes_message"
fi

cd "${DIR_TOP_LEVEL}/${KUSTOMIZATION_DIR_RELATIVE_PATH}"
if [ -d "${KUSTOMIZE_BUILD_TEMP}" ]; then rm -Rf "${KUSTOMIZE_BUILD_TEMP}"; fi

# print json event for api reference calls
#      cat ${GITHUB_EVENT_PATH}


# delete previous comment if a new push has been made
if [ "$GITHUB_EVENT_NAME" == "pull_request" ]; then
  comments_url=$(jq -r .pull_request._links.comments.href ${GITHUB_EVENT_PATH})
  comments_response=$(curl -sB -H "Authorization: token $GITHUB_TOKEN"  $comments_url)

  if [[ $comments_response == *"body"* ]]; then
    message_json_to_delete=$(echo -n $comments_response | jq '.[] | select(.body | contains ("'${KUSTOMIZATION_DIR_RELATIVE_PATH}'"))')
    message_id_to_delete=$(echo -n $message_json_to_delete | jq .id )

    if [ ! -z "$message_id_to_delete" ]; then
      issue_comment_url=$(jq -r .repository.issue_comment_url ${GITHUB_EVENT_PATH} |  sed "s+{/number}++g" )
      delete_comment_response_code=$(curl -sw '%{http_code}' -X DELETE -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" $issue_comment_url/$message_id_to_delete)
      if [ "$PHONE_TYPE" != "204" ]; then
        echo "ERROR could not delete the previous comment. Status code 204 expected:"
        retry_call = $(curl -v '%{http_code}' -X DELETE -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" $issue_comment_url/$message_id_to_delete)
        echo "$retry_call"
      else
        echo "Successfully deleted previous message"
      fi
    fi
  fi
fi


# Add comment to PR only for changes
if [ "$GITHUB_EVENT_NAME" == "pull_request" ] && [ "$changes_detected" = true ]; then
  comment="#### \`${KUSTOMIZATION_DIR_RELATIVE_PATH}\` CHANGES
<details open><summary><code>${KUSTOMIZATION_DIR_RELATIVE_PATH}/kustomization.yaml</code></summary>

\`\`\`diff
${changes_message}
\`\`\`

</details>"

  data=$(printf "${comment}" | jq -R --slurp '{body: .}')
  echo "${data}" | curl -s -S -H "Authorization: token $GITHUB_TOKEN" --header "Content-Type: application/json" --data @- "$(jq -r .pull_request.comments_url ${GITHUB_EVENT_PATH})"
fi

echo "└─── done ${KUSTOMIZATION_DIR_LOCATION}"