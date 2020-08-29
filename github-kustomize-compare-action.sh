#!/bin/bash

# get dependencies in context
mkdir -p ~/binkustomization && export PATH=~/binkustomization:$PATH

if [ ! -f ~/binkustomization/yq ];then
  wget -cO - https://github.com/mikefarah/yq/releases/download/3.3.2/yq_linux_amd64 > ~/binkustomization/yq && chmod +755 ~/binkustomization/yq
fi
if [ ! -f ~/binkustomization/jq ];then
  wget -cO - https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 > ~/binkustomization/jq && chmod +755 ~/binkustomization/jq
fi
if [ ! -f ~/binkustomization/kubectl ];then
  wget -cO - https://storage.googleapis.com/kubernetes-release/release/v1.18.0/bin/linux/amd64/kubectl > ~/binkustomization/kubectl && chmod +755 ~/binkustomization/kubectl
fi
if [ ! -f ~/binkustomization/kustomize ];then
  wget -cO - https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v3.8.1/kustomize_v3.8.1_linux_amd64.tar.gz > kustomize.tar.gz
  tar xzf kustomize.tar.gz && rm kustomize.tar.gz && mv kustomize ~/binkustomization
fi


.github/workflows/kustomize-compare-action.sh probe-phrase-search/kustomize/overlays/dev
.github/workflows/kustomize-compare-action.sh probe-phrase-search/kustomize/overlays/prod



