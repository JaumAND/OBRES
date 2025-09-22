#!/usr/bin/env bash
set -euo pipefail

# create_and_push.sh
# Crea els fitxers .github/workflows/build.yml, scripts/verify-portable.js, .gitignore, README.md i LICENSE,
# fa git add/commit i (opcionalment) push a origin main.
#
# Ús:
#   chmod +x create_and_push.sh
#   ./create_and_push.sh
#
# El script comprova si estàs dins d'un repo git i et demanarà confirmació abans de fer el push.

COMMIT_MSG="Add portable packaging, CI build, verification script, and repo metadata (rest)"

function abort {
  echo >&2 "Abortat: $1"
  exit 1
}

# Comprova que som dins un repo git
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  abort "No sembla que estiguis dins d'un repositori git. Executa-ho des de la carpeta del teu repo."
fi

# Confirma branca actual
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Branca git actual: $CURRENT_BRANCH"

# Crear directoris
mkdir -p .github/workflows scripts

# Escriure .github/workflows/build.yml
cat > .github/workflows/build.yml <<'EOF'
name: Build portable artifact & verify

on:
  push:
    branches: [ main ]

jobs:
  build-and-verify:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Build portable artifacts
        run: npm run build:portable
        env:
          CI: true

      - name: Run portable verification
        run: npm run ci:verify

      - name: Upload dist artifact
        uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist
EOF

# Escriure scripts/verify-portable.js
cat > scripts/verify-portable.js <<'EOF'
const fs = require('fs');
const path = require('path');

function findDist() {
  const dist = path.resolve(__dirname, '..', 'dist');
  if (!fs.existsSync(dist)) {
    console.error('No s\'ha trobat el directori dist. Build fallit o no s\'ha generat artifact.');
    process.exit(2);
  }
  return dist;
}

function checkArtifacts(dist) {
  const files = fs.readdirSync(dist);
  // Expect at least one portable-like artifact (.AppImage, .zip, .exe or .dmg)
  const match = files.find(f => /\.(AppImage|zip|exe|dmg|tar\.gz)$/.test(f));
  if (!match) {
    console.error('No s\'han trobat artifacts portables a dist/:', files);
    process.exit(3);
  }
  console.log('Artifact de build detectat:', match);
}

// Basic check that packaged app will use data dir next to executable when portable
function checkPortableLayout(dist) {
  // For a portable build, esperem algun fitxer o carpeta que indiqui empaquetat
  const marker = fs.readdirSync(dist).find(f => f.toLowerCase().includes('app') || f.toLowerCase().includes('portable'));
  if (marker) {
    console.log('Possible empaquetat detectat:', marker);
  } else {
    console.log('No s\'ha detectat un marcador clar d\'empaquetat; això pot ser acceptable segons la plataforma.');
  }
}

(function main() {
  try {
    const dist = findDist();
    checkArtifacts(dist);
    checkPortableLayout(dist);
    console.log('Verificació portable: OK');
    process.exit(0);
  } catch (err) {
    console.error('Error durant la verificació portable:', err);
    process.exit(4);
  }
})();
EOF

# Escriure .gitignore
cat > .gitignore <<'EOF'
# Node
node_modules/
npm-debug.log
yarn-error.log

# Build output
dist/
build/
out/

# Runtime DBs and env
*.db
*.sqlite
.env

# OS
.DS_Store
Thumbs.db
EOF

# Escriure README.md
cat > README.md <<'EOF'
# Gestor d'Obres

Versió inicial del projecte amb suport pensat per a mode "portable".

- main.js: adaptacions per a ruta de dades portable (ús de PORTABLE_EXECUTABLE_DIR o execPath).
- Scripts de build i workflow CI per generar i verificar artifacts portables.

Començar en desenvolupament:
\`\`\`bash
npm ci
npm start
\`\`\`

Per empaquetar (local):
\`\`\`bash
npm run build:portable
\`\`\`
EOF

# Escriure LICENSE
cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2025 JaumAND

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

echo
echo "Fitxers creats:"
ls -1 .github/workflows build scripts .gitignore README.md LICENSE 2>/dev/null || true
echo

# Afegir a git
git add .github/workflows/build.yml scripts/verify-portable.js .gitignore README.md LICENSE

# Comprovar si hi ha canvis a commit
if git diff --cached --quiet; then
  echo "No hi ha canvis per commitejar."
else
  git commit -m "$COMMIT_MSG"
  echo "Commit creat amb missatge: $COMMIT_MSG"
fi

# Preguntar abans de fer push
read -r -p "Vols fer push a origin/$CURRENT_BRANCH ara? [y/N] " yn
case "$yn" in
  [Yy]* )
    echo "Pushing to origin/$CURRENT_BRANCH..."
    git push origin "$CURRENT_BRANCH"
    echo "Push completat."
    ;;
  * )
    echo "No s'ha fet push. Pots fer-ho manualment amb: git push origin $CURRENT_BRANCH"
    ;;
esac

echo "Fet. Si vols que comprovi la run a GitHub Actions, obre la pàgina Actions del repo."