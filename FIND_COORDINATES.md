# Guide : Trouver les coordonnées du bouton Play

Ce guide vous explique plusieurs méthodes pour trouver les coordonnées X,Y du bouton play sur votre page web.

## 🎯 Méthode 1 : Outils de développement du navigateur (Recommandée)

### Étape 1 : Ouvrir les outils de développement

1. Ouvrez votre page web dans un navigateur (Chrome, Firefox, Edge, etc.)
2. Appuyez sur **F12** ou faites un **clic droit** → **Inspecter**
3. Les outils de développement s'ouvrent en bas ou sur le côté

### Étape 2 : Sélectionner le bouton

1. Cliquez sur l'icône **"Sélectionner un élément"** (icône de curseur en haut à gauche des outils)
   - Ou appuyez sur **Ctrl+Shift+C** (Windows/Linux) ou **Cmd+Shift+C** (Mac)
2. Survolez le bouton play avec votre souris
3. Le bouton sera surligné
4. Cliquez sur le bouton play

### Étape 3 : Trouver les coordonnées

Une fois le bouton sélectionné dans le code HTML :

**Option A : Via la console JavaScript**

1. Dans les outils de développement, allez dans l'onglet **Console**
2. Tapez ou copiez-collez ce code :

```javascript
// Si le bouton a un ID
const btn = document.getElementById('play-button-id');

// OU si le bouton a une classe
const btn = document.querySelector('.play-button');

// OU si c'est un bouton HTML5 audio/video
const btn = document.querySelector('button[aria-label="Play"]');

// OU trouvez le bouton manuellement dans le code HTML et utilisez son sélecteur
const btn = document.querySelector('votre-selecteur-ici');

// Obtenir les coordonnées du centre du bouton
if (btn) {
  const rect = btn.getBoundingClientRect();
  const centerX = Math.round(rect.left + rect.width / 2);
  const centerY = Math.round(rect.top + rect.height / 2);
  console.log('Coordonnées du centre du bouton:');
  console.log('X:', centerX);
  console.log('Y:', centerY);
  console.log('Format pour Docker:', `"${centerX},${centerY}"`);
} else {
  console.error('Bouton non trouvé! Vérifiez le sélecteur.');
}
```

3. Appuyez sur **Entrée**
4. Les coordonnées s'affichent dans la console

**Option B : Via l'inspecteur d'éléments**

1. Avec le bouton sélectionné dans le code HTML
2. Regardez dans le panneau de droite (ou en bas) les propriétés CSS
3. Cherchez les valeurs de `position`, `left`, `top`, `width`, `height`
4. Calculez : 
   - X = left + (width / 2)
   - Y = top + (height / 2)

## 🖱️ Méthode 2 : Extension navigateur (Plus facile)

### Pour Chrome/Edge :

1. Installez l'extension **"Page Ruler"** ou **"MeasureIt"**
2. Ouvrez votre page
3. Activez l'extension
4. Survolez le bouton play
5. Les coordonnées s'affichent

### Pour Firefox :

1. Installez l'extension **"MeasureIt"**
2. Même processus que ci-dessus

## 📐 Méthode 3 : Calcul manuel (Si vous connaissez la position)

Si vous savez approximativement où se trouve le bouton :

- **Pour une résolution 1920x1080** :
  - Centre de l'écran : `960,540`
  - Si le bouton est en haut à gauche : `100,100`
  - Si le bouton est en bas à droite : `1820,980`

- **Pour une résolution 1280x720** :
  - Centre de l'écran : `640,360`

## 🔍 Méthode 4 : Script automatique dans la console

Copiez-collez ce script dans la console pour trouver automatiquement le bouton play :

```javascript
// Script pour trouver automatiquement le bouton play
function findPlayButton() {
  // Liste de sélecteurs communs pour les boutons play
  const selectors = [
    'button[aria-label*="play" i]',
    'button[aria-label*="Play" i]',
    'button.play',
    'button[class*="play" i]',
    '.play-button',
    '[data-testid*="play" i]',
    'button:has(svg[class*="play" i])',
    'video + button',
    'audio + button',
    'button[title*="play" i]'
  ];
  
  let button = null;
  
  for (const selector of selectors) {
    try {
      button = document.querySelector(selector);
      if (button) {
        console.log('Bouton trouvé avec le sélecteur:', selector);
        break;
      }
    } catch (e) {
      // Ignorer les sélecteurs invalides
    }
  }
  
  if (!button) {
    // Chercher tous les boutons et afficher leurs positions
    const buttons = document.querySelectorAll('button');
    console.log('Aucun bouton play trouvé automatiquement.');
    console.log('Boutons disponibles sur la page:');
    buttons.forEach((btn, index) => {
      const rect = btn.getBoundingClientRect();
      console.log(`Bouton ${index + 1}:`, {
        text: btn.textContent.trim().substring(0, 30),
        x: Math.round(rect.left + rect.width / 2),
        y: Math.round(rect.top + rect.height / 2),
        selector: btn.className || btn.id || 'button'
      });
    });
    return null;
  }
  
  const rect = button.getBoundingClientRect();
  const centerX = Math.round(rect.left + rect.width / 2);
  const centerY = Math.round(rect.top + rect.height / 2);
  
  console.log('✅ Bouton play trouvé!');
  console.log('Coordonnées du centre:');
  console.log('X:', centerX);
  console.log('Y:', centerY);
  console.log('\n📋 Format pour Docker:');
  console.log(`PLAY_BUTTON_COORDS="${centerX},${centerY}"`);
  console.log('\n📋 Format pour Railway (dans les variables):');
  console.log(`PLAY_BUTTON_COORDS = ${centerX},${centerY}`);
  
  // Surligner le bouton
  button.style.outline = '3px solid red';
  button.style.outlineOffset = '2px';
  
  return { x: centerX, y: centerY };
}

// Exécuter la fonction
findPlayButton();
```

## 🎬 Exemple pratique

Supposons que votre page a un bouton play avec cette structure HTML :

```html
<button class="play-button" id="music-play">
  ▶ Play
</button>
```

**Dans la console, exécutez :**

```javascript
const btn = document.querySelector('.play-button');
const rect = btn.getBoundingClientRect();
const x = Math.round(rect.left + rect.width / 2);
const y = Math.round(rect.top + rect.height / 2);
console.log(`PLAY_BUTTON_COORDS="${x},${y}"`);
```

**Résultat possible :**
```
PLAY_BUTTON_COORDS="960,540"
```

## ✅ Vérification

Pour vérifier que les coordonnées sont correctes :

1. Ouvrez votre page
2. Ouvrez la console (F12)
3. Exécutez ce code (remplacez X et Y par vos coordonnées) :

```javascript
// Simuler un clic aux coordonnées
const x = 960; // Remplacez par votre X
const y = 540; // Remplacez par votre Y

// Créer un événement de clic
const event = new MouseEvent('click', {
  view: window,
  bubbles: true,
  cancelable: true,
  clientX: x,
  clientY: y
});

// Trouver l'élément à cette position
const element = document.elementFromPoint(x, y);
if (element) {
  console.log('Élément trouvé aux coordonnées:', element);
  element.dispatchEvent(event);
  console.log('Clic simulé!');
} else {
  console.log('Aucun élément trouvé à ces coordonnées');
}
```

## 🚀 Utilisation dans Docker

Une fois que vous avez les coordonnées, utilisez-les ainsi :

```bash
docker run -d --rm \
  --name stream \
  --shm-size=2gb \
  -e TARGET_URL="https://votre-page.com" \
  -e RTMP_URL="rtmps://votre-serveur.com/stream/key" \
  -e PLAY_BUTTON_COORDS="960,540" \
  web-streamer
```

## 🚂 Utilisation dans Railway

Dans Railway, ajoutez la variable d'environnement :

- **Nom** : `PLAY_BUTTON_COORDS`
- **Valeur** : `960,540` (sans guillemets)

## 💡 Conseils

1. **Utilisez le centre du bouton** : Les coordonnées doivent pointer vers le centre du bouton, pas le coin
2. **Testez plusieurs fois** : Les coordonnées peuvent varier légèrement selon la taille de la fenêtre
3. **Prenez en compte le zoom** : Si votre navigateur est zoomé, les coordonnées seront différentes
4. **Résolution de l'écran** : Les coordonnées sont relatives à la fenêtre du navigateur, pas à l'écran physique
5. **Page responsive** : Si votre page s'adapte à la taille, testez avec la même résolution que celle configurée dans `RESOLUTION`

## 🐛 Problèmes courants

**Le bouton n'est pas cliqué :**
- Vérifiez que les coordonnées sont correctes
- Augmentez `PLAY_BUTTON_DELAY` pour laisser plus de temps à la page de charger
- Vérifiez que le bouton est visible (pas caché par un overlay)

**Les coordonnées changent :**
- Assurez-vous que la résolution de votre navigateur correspond à `RESOLUTION` dans Docker
- Vérifiez que la page ne se redimensionne pas dynamiquement

**Le bouton est cliqué trop tôt :**
- Augmentez `PLAY_BUTTON_DELAY` (par exemple, `10` secondes au lieu de `5`)

