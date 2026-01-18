#!/opt/homebrew/bin/bash

gotpl metrics-config.tpl < user-crds-inventory.yml \
  > kube-state-metrics-config.yaml
