# Jot

Capture rapide de notes techniques pour développeurs — desktop d'abord
(Windows), avec macOS/Linux et mobile en secondaire.

Jot est pensé pour deux gestes, et rien d'autre :

- **noter en quelques secondes** une valeur, un bout de JSON, un snippet, une
  URL ou une clé, sans quitter la tâche en cours ;
- **la retrouver instantanément** plus tard, en la reconnaissant d'un coup
  d'œil grâce au badge de type et à la coloration syntaxique.

Ces deux exigences ont tranché tous les arbitrages non couverts par la
maquette : pas de confirmation superflue, pas de dialogue bloquant, les erreurs
de fichiers sont signalées dans un bandeau discret plutôt qu'en modale.

## Lancer

```bash
flutter run -d windows
```

Aperçu de la vue mobile sans émulateur (fenêtre 390×844) :

```bash
flutter run -d windows --dart-define=JOT_FORCE_MOBILE=true
```

Après toute modification des tables `drift` :

```bash
dart run build_runner build
```

## Le coffre

Les notes sont des fichiers `.md` dans `~/JotVault/`, un sous-dossier par
dossier de l'application. Les fichiers font foi ; l'index SQLite n'est qu'un
cache jetable.

```markdown
---
id: "ab6bb229-3db9-4e37-9b52-c789ccb99aa8"
title: "webhook checkout.session"
type: json
tags: ["api", "stripe"]
folder: "Inbox"
created: 2026-07-28T09:12:00.000
modified: 2026-07-30T15:55:50.000
pinned: true
---
{ "id": "evt_1PqR2sK9xLmT4uV" }
```

Un `.md` déposé à la main sans frontmatter est lu quand même : le titre vient
du premier titre ou de la première ligne, le type est deviné, le dossier vient
du chemin.

Au premier lancement — et uniquement si `~/JotVault/` n'existait pas — quelques
notes d'exemple sont créées pour que l'application démarre sur quelque chose de
vivant.

## Recherche

L'index est une base SQLite (`drift`) avec une table FTS5, tenue à jour en
tâche de fond par un `watcher` sur le coffre. Toute création, modification ou
suppression de fichier — y compris depuis un autre éditeur — met l'index à jour
dans les ~220 ms.

La recherche combine deux passes :

1. **FTS5** en préfixe, rapide et classée par pertinence ;
2. **sous-chaîne**, parce qu'un développeur cherche `hook` pour trouver
   `webhook_failed`, ce qu'une recherche par tokens ne peut structurellement
   pas rendre.

Il n'y a **pas de debounce** sur la frappe : sur quelques centaines de notes la
requête coûte quelques millisecondes, et attendre 150 ms est exactement la
friction que cette application existe pour supprimer.

Si l'index est absent, corrompu ou d'un schéma périmé, il est supprimé et
reconstruit intégralement depuis le coffre — un cache cassé n'est jamais une
raison de faire échouer un démarrage.

## Écrans

| Écran | Fichier | Raccourci |
|---|---|---|
| Fenêtre principale, 3 colonnes | `features/main_window/` | — |
| Palette de recherche | `features/search_palette/` | `Ctrl K` |
| Capture rapide (fenêtre séparée) | `features/quick_capture/` | `Ctrl Alt N` (global) |
| Vue mobile (liste → détail) | `features/mobile/` | — |

La capture rapide est une vraie fenêtre système (`desktop_multi_window`), avec
son propre moteur Flutter : elle n'a besoin ni de l'index ni du watcher, elle
écrit un fichier et se ferme. Si la plateforme refuse de créer la fenêtre,
l'application bascule automatiquement sur un overlay in-app — la capture est la
seule chose qui ne doit jamais être indisponible.

## Design

Tout vient de `Jot.dc.html` (Claude Design), extrait dans `core/theme/` :

- `jot_colors.dart` — la rampe anthracite, l'accent unique `#FF6A3D`, les
  couleurs de badge par type et la palette de syntaxe ;
- `jot_typography.dart` — police système pour l'interface, JetBrains Mono pour
  tout contenu (JSON, code, URL, clés, compteurs, keycaps) ;
- `jot_metrics.dart` — dimensions fixes : fenêtre 1360×860, colonnes 236 / 340,
  palette 760, capture 540.

JetBrains Mono est utilisée si elle est installée ; sinon la chaîne de repli
tombe sur la monospace de développement de la plateforme. Pour un rendu au
pixel près, déposer les `.ttf` dans `assets/fonts/` et les déclarer dans
`pubspec.yaml`.

## Tests

```bash
flutter test
```

Couvre la détection de type et l'aller-retour disque du frontmatter (collisions
de noms, renommage, fichier illisible, `.md` sans frontmatter).
