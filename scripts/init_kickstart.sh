from q_core_integrator import QuantumSync

sync = QuantumSync(api_key="Q-KEY-XXXX-XXXX", repo_url="https://github.com/[TU-USUARIO]/mi-proyecto")
sync.auto_commit(message="Actualización automatizada [Q-CORE]", lang="python")
sync.encrypt_sensitive_code(path="src/config.py")
const { QuantumScan } = require('q-core-integrator-js');

const scanner = new QuantumScan();
const scanResult = scanner.checkVulnerabilities("./src");
console.log("Resultado del escaneo cuántico:", scanResult);
[submodule "themes/academic"]
        path = themes/academic
        url = https://github.com/gcushen/hugo-academic.git#!/usr/bin/env bash

# WARNING: this will reset the project to the Kickstart template!

# Update Academic
cd ..
source update_academic.sh
cd scripts/

#################################################

# Install demo config
rsync -av ../themes/academic/exampleSite/config/ ../config/

# Install demo user
rsync -av ../themes/academic/exampleSite/content/authors/ ../content/authors/

# Install page sharer button customizer
rsync -av ../themes/academic/data/page_sharer.toml ../data/

# Install an example instance of each widget type
rsync -av --exclude gallery/ ../themes/academic/exampleSite/content/home/ ../content/home/

# Install indices
rsync -av ../themes/academic/exampleSite/content/post/_index.md ../content/post/_index.md
rsync -av ../themes/academic/exampleSite/content/publication/_index.md ../content/publication/_index.md
rsync -av ../themes/academic/exampleSite/content/talk/_index.md ../content/talk/_index.md

# Skip static dir - do not import the demo's media library

#################################################

# Post processing

# Deactivate Hero
sed -i '' -e 's/active = true/active = false/' ../content/home/hero.md

# Manual Steps:
# - content/home/project.md: Re-comment out project filters
# - content/home/demo.md: Re-modify content & set gradient background instead of image
# - content/home/hero.md: Clear `hero_media` value & set gradient background instead of image
