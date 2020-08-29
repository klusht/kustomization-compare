# kustomization diff / compare for local run and github actions

Handy script to help you visualize the changes done by kustomize. Use it in github actions to validate kustomization yaml files.

## Usage:
- Download the script present in .github/workflows/kustomize-compare-action.sh and place it under the same location in your repo ( it is meant to be used in github actions as well )
- Download  “github-kustomize-compare-action.sh” and place it in your repo root folder
- Edit github-kustomize-compare-action.sh to point to a root overlay kustomization.yaml file
- Run in terminal ./github-kustomize-compare-action.sh 

Output example
``` 
┌─── kustomize-compare-action probe-phrase-search/kustomize/overlays/dev
┝ Comparing kustomize build probe-phrase-search/kustomize/overlays/dev/kustomization.yaml
┝ Branch github-actions-kustomize-apply with code from origin/master branched off commit aa31a405b306b38c0afc85d597f2e7d7a58db505
┝ ✓️ Building kustomize for current code in probe-phrase-search/kustomize/overlays/dev/kustomize_build_temp
┝ ✓️ Get previous code version
┝ ✓️ Processing files to compare

***** UPDATED OBJECT 
| apiVersion: apps/v1
| kind: Deployment
| metadata:
|   name: my-nginx
|   namespace: default
+------------------
@@ -7 +7 @@ spec:
-  replicas: 3
+  replicas: 5
-------------------
└─── done probe-phrase-search/kustomize/overlays/dev
┌─── kustomize-compare-action probe-phrase-search/kustomize/overlays/prod
┝ Comparing kustomize build probe-phrase-search/kustomize/overlays/prod/kustomization.yaml
┝ Branch github-actions-kustomize-apply with code from origin/master branched off commit aa31a405b306b38c0afc85d597f2e7d7a58db505
┝ ✓️ Building kustomize for current code in probe-phrase-search/kustomize/overlays/prod/kustomize_build_temp
┝ ✓️ Get previous code version
┝ ✓️ Processing filesg to compare
┝ ✗  No changes detected for probe-phrase-search/kustomize/overlays/prod/kustomization.yaml
└─── done probe-phrase-search/kustomize/overlays/prod
```

Example adding pull request comment 
![comments Image](https://github.com/klusht/kustomization-compare/blob/master/resources/comment_example.png)



## Benefits:
- automates the validation of kustomize changes and fails if kustomize files are not correct
- It can be used locally and in github actions to block merging the issues. 
- It adds comments to PR to show the end result of kustomize. Old comments are deleted when new code is pushed to branch
- The code is in bash to allow direct changes, also no dependencies on this repo.
- You can have your github actions private. 


#### Description

The main script is intended  to support code reviews on pull requests to understand the end result of kustomize changes. You can do this process manually by using `kustomize build . > result.yaml` and  search the objects that you remember you changed. To make sure no other breaking changes are present, also search the code that nothing else is different. Be carfule especially when you use specialized kustomize directives that can change multiple objects (common labels for example).

This process is present in the bash script and only prints the changes for you.

#### Limitations:
- It depends on yq and kustomize binaries (code is automated to fetch them)
- It does not show the source file containing the changes. For that simply use git diff if you changed too many without running the script. Also there is a comment added to the pull request and in that PR it shows what files have been changed. Maybe it will be added if there is demand. 
- It does not compare the changes with LIVE cluster. It is meant to compare your new changes with the code you branched off from “default” branch. That option is available in kubectl diff -k :) 

### Assumptions on the infrastructure:

You have a repository for some services that can be deployed in many environments when merged into the “default” branch. As the service is deployed in a kubernetes environment you will need the configuration objects yaml’s for each environment. (check the kubernetes folder)
Using kustomize cli program you can structure your deployments to heavily depend on a single source of truth from which you should diverge, mostly with the “resources allocation”.
You should have a base folder ( containing the code that represents the “default” state of your applications ) and an overlay folder that contains patches required by different environments. 

In overlay/[environment] you will have a root kustomization.yaml file that can be used in `kubectl apply -k` to provision the resources in your cluster. The apply process is your choice, although this repo will have the apply process done from github actions.



