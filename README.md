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

## Authentification et onboarding

L’application comprend les écrans de bienvenue, connexion, inscription et
complétion de profil en trois étapes. L’inscription transmet `display_name` aux
métadonnées Auth afin que le trigger Supabase crée le profil. L’onboarding lit
les tables de référence `wilayas`, `universities`, `study_levels`,
`study_fields` et `interests`, puis met à jour le profil et les intérêts du
compte connecté.

Les avatars sont limités aux images JPEG/PNG de 5 Mo maximum et sont envoyés
dans le bucket `avatars` avec un chemin unique par utilisateur.

La confirmation par e-mail est activée dans Supabase : l’inscription conduit à
une page de vérification par code OTP à six chiffres (template e-mail utilisant
`{{ .Token }}`). L’application limite les renvois à un par minute et affiche un
message adapté si Supabase renvoie `over_email_send_rate_limit`.

Pour le développement et la production, configurez `Auth > URL Configuration`
avec l’URL exacte de l’application et ajoutez-la aux URL de redirection
autorisées. Configurez également un SMTP personnalisé pour l’envoi des codes.