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
