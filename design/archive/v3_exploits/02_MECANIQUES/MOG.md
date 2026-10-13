# Le Mog — réputation et duels de pose

Le Mog est **ta réputation dans la ville**. Il ne donne aucune puissance : il débloque des poses, des titres et des effets.

## 1. Comment on gagne du Mog

| Source | Mog | Remarque |
|---|---:|---|
| Premier exploit d'histoire | 10 à 40 ❓ | Une seule fois par exploit |
| Participation valide à une galère du jour | 3 à 10 ❓ | Plafonné par jour ❓ |
| Première victoire contre un rival PNJ | 10 / 20 / 30 / 40 | Une seule fois par rival |
| Duel de pose (PvP) | voir plus bas | Plafonné par paire de joueurs |

Les exploits sont la source principale ; les duels sont un **mode secondaire**.

## 2. Ce que le Mog débloque

| Mog cumulé | Déblocage |
|---:|---|
| 10 | Pose « Miroir du garage » |
| 30 | Titre « Habitué du pump » |
| 60 | Pose « Ventilation maximale » |
| 100 | Aura cartoon discrète |
| 180 | Pose « Entrée de légende » |

Les poses se choisissent dans un menu simple, avec un aperçu gratuit. Toutes ont exactement la même valeur en duel.
❓ Idée en attente : des effets d'aura qui font réagir les PNJ (voir IDEES.md).

## 3. Duels de pose (mode secondaire)

Une confrontation courte de poses et de timing sur une **estrade** de la salle de quartier.

### Invitations
- Invitation explicite, acceptation par les deux joueurs ; invitations désactivables ; spectateurs possibles.
- Pas d'invitation pendant le tutoriel, un exploit, une série ou un duel.
- 30 s entre deux invitations ; après un refus, pas de nouvelle invitation du même joueur pendant 5 min ; refus automatique après 10 s, sans pénalité.

### Déroulement
- 3 manches × 3 signaux de timing = 9 entrées. Duel de 15 à 20 s, puis une scène courte.
- Chaque entrée : score de 0 à 100 selon l'écart au centre. Fenêtre ±350 ms, Perfect ±70 ms ❓ (à ajuster selon les appareils et la latence). Entrée manquante = 0.
- Score final = moyenne des 9. Moins de 2 points d'écart = égalité.
- **Chances égales** : même motif, mêmes fenêtres. Ni la Force, ni la tenue, ni le Mog, ni l'argent n'entrent dans le calcul.

### Récompenses
- Victoire +10, égalité +6 chacun, défaite avec participation +3.
- Rien n'est jamais perdu : ni Force, ni Cash, ni objets.
- Abandon volontaire : aucune récompense. Participation valide = au moins 6 entrées acceptées.
- Récompenses limitées aux 3 premiers duels par paire de comptes et par jour (UTC). Compteur persistant et partagé entre serveurs ; si c'est impossible, désactiver les récompenses PvP en alpha.

### Mise en scène
- Le gagnant pose, les serviettes s'envolent, le perdant fait un geste comique bref.
- Pas d'annonce humiliante au serveur, pas de surnom imposé, pas de provocation ciblée.
- Réduction des secousses, effets lumineux modérés, cris à volume réglable, scènes quittables.

Le Mog est une réputation cumulée, pas un classement de compétence. Pas de classement compétitif dans le MVP.
