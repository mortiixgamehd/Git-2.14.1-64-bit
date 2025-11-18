// Envoi de toutes les zones personnalisées au serveur
function sendAllCustomZonesToServer() {
  if (!window.customZones) return
  fetch(`https://${GetParentResourceName()}/saveAllZones`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ zones: window.customZones })
  })
}

// Bouton pour sauvegarder toutes les zones (ajoutez-le dans le panel si besoin)
// Exemple d'appel : sendAllCustomZonesToServer()
// Gestion des zones personnalisées

// Chargement/sauvegarde des zones personnalisées (localStorage)
function loadCustomZones() {
  try {
    const raw = localStorage.getItem('eboueur_customZones')
    if (raw) {
      window.customZones = JSON.parse(raw)
      // Ajoute au select
      const select = document.getElementById('zone')
      Object.keys(window.customZones).forEach(name => {
        if (!Array.from(select.options).some(opt => opt.value === name)) {
          const opt = document.createElement('option')
          opt.value = name
          opt.textContent = name + ' (perso)'
          select.appendChild(opt)
        }
      })
    }
  } catch(e) { window.customZones = {} }
}

function saveCustomZones() {
  try {
    localStorage.setItem('eboueur_customZones', JSON.stringify(window.customZones || {}))
  } catch(e) {}
}

window.addEventListener('DOMContentLoaded', loadCustomZones)

let customPoints = []
document.getElementById('addPoint').addEventListener('click', function() {
  const x = parseFloat(document.getElementById('customX').value)
  const y = parseFloat(document.getElementById('customY').value)
  const z = parseFloat(document.getElementById('customZ').value)
  const type = document.getElementById('customType').value
  if (isNaN(x) || isNaN(y) || isNaN(z)) return alert('Coordonnées invalides')
  customPoints.push({ x, y, z, type })
  updateCustomList()
})

function updateCustomList() {
  const ul = document.getElementById('customList')
  ul.innerHTML = ''
  customPoints.forEach((pt, i) => {
    const li = document.createElement('li')
    li.textContent = `Point ${i+1}: (${pt.x}, ${pt.y}, ${pt.z}) - ${pt.type}`
    ul.appendChild(li)
  })
}

document.getElementById('addZone').addEventListener('click', function() {
  const name = document.getElementById('customZoneName').value.trim()
  if (!name) return alert('Nom de zone requis')
  if (customPoints.length === 0) return alert('Ajoutez au moins un point')
  // Ajoute la zone au select
  const select = document.getElementById('zone')
  if (!Array.from(select.options).some(opt => opt.value === name)) {
    const opt = document.createElement('option')
    opt.value = name
    opt.textContent = name + ' (perso)'
    select.appendChild(opt)
  }
  // Stocke la zone dans window pour l'envoyer au client
  window.customZones = window.customZones || {}
  window.customZones[name] = customPoints.map(pt => ({ pos: { x: pt.x, y: pt.y, z: pt.z }, type: pt.type }))
  saveCustomZones()
  customPoints = []
  updateCustomList()
  document.getElementById('customZoneName').value = ''
  alert('Zone personnalisée ajoutée !')
})
window.addEventListener('message', function(event) {
  const d = event.data
  if (d.action === 'toggle') {
    document.getElementById('panel').classList.toggle('hidden', !d.open)
  }
  if (d.action === 'updateData') {
    document.getElementById('level').innerText = d.data.level || 1
    document.getElementById('xp').innerText = d.data.xp || 0
  }
})


document.getElementById('start').addEventListener('click', function() {
  const zone = document.getElementById('zone').value
  let custom = null
  if (window.customZones && window.customZones[zone]) {
    custom = window.customZones[zone]
  }
  fetch(`https://${GetParentResourceName()}/startMission`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ zone, custom })
  })
    .then(r => r.json()).then(resp => {
      if (!resp.ok) alert(resp.msg || 'Impossible de démarrer la mission')
    })
})

document.getElementById('close').addEventListener('click', function() {
  fetch(`https://${GetParentResourceName()}/close`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({}) })
})
