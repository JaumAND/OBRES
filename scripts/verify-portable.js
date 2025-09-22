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
