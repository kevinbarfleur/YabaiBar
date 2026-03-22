# Philosophie VibeNotch

## Vision
VibeNotch est une plateforme notch modulaire. Le notch est le produit, les modules sont les fonctionnalités.

## Principes (NON-NEGOCIABLE)

### 1. Module-First
Toute fonctionnalité utilisateur = un module. Le core ne fait QUE :
- Afficher le notch (shape, hover, animations)
- Gérer les fenêtres per-display
- Orchestrer les modules via le registre
- Fournir les settings générales

### 2. Ship Fast, Ship Smart
- Pas d'abstraction avant 3 usages concrets
- Tests uniquement sur les chemins critiques (builders, signal handler)
- Itération rapide : modifier → build → install → tester visuellement

### 3. Animations = Expérience
Le notch est un élément visuel premium. Les animations DOIVENT être fluides :
- Spring animations uniquement (pas de linear/easeIn)
- Compositor properties (transform, opacity) préférées
- Tester visuellement après chaque changement d'animation

### 4. macOS Native
Pas de compromis cross-platform. Utiliser les APIs macOS natives :
- NSPanel, NSStatusItem, NSHapticFeedbackManager
- SMAppService pour le login item
- CGDisplay pour la détection d'écrans

### 5. Simplicité
- 3 lignes similaires > 1 abstraction inutile
- Pas de feature flags, pas de backward-compat shims
- Si c'est inutilisé, supprimer

## Périmètre BLOQUÉ
- Backend/cloud sync
- Comptes utilisateur
- Analytics
- Support iOS/iPadOS
- Modules dynamiques (bundles externes) — built-in uniquement pour v1
