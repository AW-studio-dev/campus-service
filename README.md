# 🎓 Campus Service

**Campus Service** est une plateforme web communautaire et une marketplace dédiée aux étudiants, jeunes entrepreneurs et prestataires de services en Algérie. 

L'objectif est de centraliser les échanges, de donner de la visibilité aux projets étudiants et de faciliter l'entraide au sein de la communauté universitaire.

## ⚙️ Principes de fonctionnement

L'application repose sur des règles strictes pour garantir un écosystème sain, sécurisé et équitable :

1. **Un compte unique par personne** : Il n'y a pas de distinction entre un compte "acheteur" et un compte "vendeur". Chaque membre possède un compte personnel unique qui lui permet d'acheter, de vendre, de publier et de communiquer.
2. **Une seule vitrine par membre** : Un utilisateur peut créer au maximum **un seul profil Business** (sa vitrine professionnelle) rattaché à son compte personnel. Cette règle est garantie par la base de données.
3. **Zéro paiement intégré** : Campus Service ne gère aucun transfert d'argent. Le bouton principal d'une annonce est « Contacter le vendeur ». La négociation et le règlement se font directement entre les parties (par messagerie ou en dehors de la plateforme).
4. **Sécurité et Confidentialité** : Les messages privés sont strictement confidentiels (grâce aux règles RLS) et ne sont accessibles qu'aux participants de la conversation.
5. **Modération et Administration** : Une application Admin séparée permet de gérer les signalements, les rôles et de veiller au respect des règles communautaires.

## 🚀 Fonctionnalités principales
*   **Réseau social** : Fil d'actualité, publications, commentaires, réactions et abonnements.
*   **Marketplace** : Vitrines Business, catalogue de services et de produits (avec images).
*   **Demandes étudiantes** : Un espace dédié pour demander de l'aide scolaire ou chercher des partenaires de projet.
*   **Messagerie privée** : Discussions directes et sécurisées entre membres.

## Écrans Flutter disponibles

L’application comprend l’inscription avec ouverture de session directe lorsque
la confirmation e-mail est désactivée dans Supabase, la connexion, la
réinitialisation du mot de passe, le fil social (posts, images, réactions,
commentaires et favoris), les demandes d’aide, la recherche, les profils et
leur édition, la messagerie, les notifications, les paramètres, les
signalements, ainsi que le marketplace et les vitrines business (offres, avis
et tableau de bord).

La messagerie s’abonne aux nouveaux messages Supabase Realtime et actualise
aussi la conversation périodiquement comme solution de repli. Pour une
actualisation instantanée, activez `messages` dans la publication Realtime de
Supabase. Les notifications apparaissent lorsque les triggers ou Edge
Functions du backend les insèrent dans `notifications`.

## 🛠️ Stack Technique
*   **Frontend** : Flutter Web (Dart)
*   **Backend & Base de données** : Supabase (PostgreSQL)
*   **Hébergement** : Cloudflare Pages (prévu)

## Configuration locale

1. Copiez `.env.example` vers `.env`.
2. Renseignez `SUPABASE_URL` et `SUPABASE_ANON_KEY` avec les valeurs du projet
   Supabase. Utilisez uniquement la clé publique anon/publishable dans Flutter ;
   ne placez jamais la clé `service_role` dans l’application.
3. Lancez `flutter pub get`, puis `flutter run`.

Le fichier `.env` est ignoré par Git. L’application initialise Supabase avant
de démarrer et protège `/home` avec l’état de session Supabase.

## Déploiement Cloudflare Pages

Dans les paramètres du projet Cloudflare Pages, ajoutez les variables de build
`SUPABASE_URL` et `SUPABASE_ANON_KEY` pour les environnements Production et
Preview. Utilisez l’URL du projet Supabase et sa clé publique anon/publishable ;
ne configurez jamais `service_role`.

Configurez le répertoire racine sur `/`, puis utilisez la commande de build
suivante afin de créer l’asset `.env` ignoré par Git avant la compilation :

```bash
printf 'SUPABASE_URL=%s\nSUPABASE_ANON_KEY=%s\n' "$SUPABASE_URL" "$SUPABASE_ANON_KEY" > .env
flutter pub get
flutter build web --release --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

Le répertoire de sortie Cloudflare doit être `build/web`. Si le build échoue
avec `flutter: command not found`, configurez un environnement de build qui
installe le SDK Flutter avant d’exécuter ces commandes.

## Authentification et onboarding

L’application comprend les écrans de bienvenue, connexion, inscription et
complétion de profil en trois étapes. L’inscription transmet `display_name` aux
métadonnées Auth afin que le trigger Supabase crée le profil. L’onboarding lit
les tables de référence `wilayas`, `universities`, `study_levels`,
`study_fields` et `interests`, puis met à jour le profil et les intérêts du
compte connecté.

Les avatars sont limités aux images JPEG/PNG de 5 Mo maximum et sont envoyés
dans le bucket `avatars` avec un chemin unique par utilisateur.

Pour ouvrir une session immédiatement après l’inscription, désactivez
`Authentication > Providers > Email > Confirm email` dans Supabase. Dans ce
mode, Supabase doit retourner une session après `signUp`; l’application envoie
alors l’utilisateur vers le splash puis l’onboarding si son profil est
incomplet. Si Supabase ne retourne pas de session, l’application indique que la
confirmation est encore requise au lieu de prétendre contourner Auth.

Les utilisateurs déjà créés sans confirmation peuvent devoir être confirmés
depuis `Authentication > Users`. Désactiver la confirmation signifie que
Supabase ne valide plus la propriété de l’adresse e-mail lors de l’inscription.

La réinitialisation du mot de passe redirige vers l’adresse courante de
l’application, sur `/#/reset-password`. Ajoutez cette URL de redirection
Firebase, ainsi que l’URL locale de développement si nécessaire, dans
`Authentication > URL Configuration > Redirect URLs` de Supabase. L’événement
`passwordRecovery` ouvre le formulaire de nouveau mot de passe.

Pour le développement et la production, configurez `Auth > URL Configuration`
avec l’URL exacte de l’application et ajoutez-la aux URL de redirection
autorisées. Configurez également un SMTP personnalisé pour l’envoi des codes.