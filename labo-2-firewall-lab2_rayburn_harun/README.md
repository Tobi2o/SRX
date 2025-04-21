
[![Review Assignment Due Date](https://classroom.github.com/assets/deadline-readme-button-24ddc0f5d75046c5622901739e7c5dd533143b0c8e959d652212380cedb1ea36.svg)](https://classroom.github.com/a/qqWUWp73)
[![Open in Visual Studio Code](https://classroom.github.com/assets/open-in-vscode-718a45dd9cf7e7f842a935f5ebbe5719a5e09af4491e668f4dbf3b35d5cca122.svg)](https://classroom.github.com/online_ide?assignment_repo_id=14203418&assignment_repo_type=AssignmentRepo)
# HEIGVD - Sécurité des Réseaux - 2024
# Laboratoire n°2 - Firewall

**Travail à réaliser en équipes de deux personnes.**

Vous pouvez répondre aux questions en modifiant directement votre clone du README.md ou avec un fichier pdf que vous pourrez uploader sur votre fork.

Le rendu consiste simplement à compléter toutes les parties marquées avec la mention "LIVRABLE". Le rendu doit se faire par un `git commit` sur la branche `main`.

## Table de matières

[Introduction](#introduction)

[Echéance](#echéance)

[Topologie](#topologie)

[Adressage](#plan-dadressage)

[Cahier des charges du réseau](#cahier-des-charges-du-réseau)

[Regles de filtrage](#regles-de-filtrage)

[Installation de l’environnement virtualisé](#installation-de-lenvironnement-virtualisé)

[Tests des connections et exemple de l'application d'une règle](#tests-des-connections-et-exemple-de-lapplication-dune-règle)

[Règles pour le protocole DNS](#règles-pour-le-protocole-dns)

[Règles pour les protocoles HTTP et HTTPS](#règles-pour-les-protocoles-http-et-https)

[Règles pour le protocole ssh](#règles-pour-le-protocole-ssh)

[Règles finales](#règles-finales)

# Introduction

L’objectif principal de ce laboratoire est de familiariser les étudiants avec les pares-feu et en particulier avec `netfilter` et `nftables`, le successeur du vénérable `iptables`.
En premier, une partie théorique permet d’approfondir la rédaction de règles de filtrage.

Par la suite, la mise en pratique d’un pare-feu permettra d’approfondir la configuration et l’utilisation d’un pare-feu ainsi que la compréhension des règles.

La [documentation nftables](https://wiki.nftables.org/wiki-nftables/index.php/Main_Page) est très complète. Vous en aurez besoin pour réaliser ce laboratoire et pour répondre à certaines questions.

La documentation contient aussi un excellent résumé pour "[apprendre nftables en 10 minutes](https://wiki.nftables.org/wiki-nftables/index.php/Quick_reference-nftables_in_10_minutes)" qui peut vous être utile.

## Auteurs

Ce texte se réfère au laboratoire « Pare-feu » à suivre dans le cadre du cours Sécurité des Réseaux, 2024, version 10.0.  Au cours du temps, il a été rédigé, modifié et amélioré par les co-auteurs suivants : Gilles-Etienne Vallat, Alexandre Délez, Olivia Manz, Patrick Mast, Christian Buchs, Sylvain Pasini, Vincent Pezzi, Yohan Martini, Ioana Carlson, Abraham Rubinstein, Frédéric Saam, Linus Gasser et Lucas Gianinetti.

## Echéance

Ce travail devra être rendu le mercredi après la fin de la 2ème séance de laboratoire, soit au plus tard, **le mercredi, 20 Mars 2024, à 23h59.**

# Réseaux cible

## Topologie

Durant ce laboratoire, nous allons utiliser une seule topologie réseau :

![Topologie du réseau virtualisé](figures/Topologie.png)

Notre réseau local (LAN) sera connecté à Internet (WAN) à travers d’un pare-feu. Nous placerons un serveur Web en zone démilitarisée (DMZ).

Par conséquent, nous distinguons clairement trois sous-réseaux :

- Internet (WAN), le réseau de l'école ou votre propre réseau servira de WAN,
- le réseau local (LAN),
- la zone démilitarisée (DMZ).

Ce réseau sera créé de manière virtuelle. Il sera simulé sur un seul ordinateur utilisant trois conteneurs Docker basés sur le système d’exploitation Ubuntu :

- La première machine, Firewall, fait office de pare-feu. Elle comporte trois interfaces réseaux. Afin que ce poste puisse servir de pare-feu dans notre réseau, nftables sera utilisé.
- La seconde machine, Client\_In\_LAN, fait office de client dans le réseau local (LAN).
- La dernière machine, Server\_In\_DMZ, fait office de serveur Web en (DMZ).

Nous allons utiliser les trois interfaces réseaux de la machine Firewall afin de pouvoir connecter le LAN et la DMZ à Internet (WAN). Les machines Client\_In\_LAN et Server\_In\_DMZ comportent chacune une interfaces réseau eth0.

## Plan d'adressage

Afin de bien spécifier le réseau, il est nécessaire d’avoir un plan d'adressage précis. C'est la liste des réseaux que vous utiliserez, comprenant pour chaque interface l'adresse IP ainsi que le masque de sous-réseau.
Pour ce laboratoire, nous vous imposons le plan d’adressage suivant :

- Le réseau "LAN" &rarr; 192.168.100.0/24
- Le réseau "DMZ" &rarr; 192.168.200.0/24
- Le réseau "WAN" sera défini par le NAT interne du réseau Docker

Les adresses IP sont définies dans le schéma ci-dessous :

![Plan d'adressage](figures/Plan.png)

## Cahier des charges du réseau

Avant de configurer les règles, il est primordial de connaître les besoins de notre réseau. Ceci afin de laisser passer les flux légitimes lors de la rédaction des règles.

Le but du **LAN** est de fournir aux utilisateurs de votre réseau un accès à Internet ; à certains services de base uniquement en empêchant les connexions provenant de l'extérieur. Il faudra tout de même laisser entrer les paquets répondants aux requêtes de notre LAN. Une seule machine est présente sur ce réseau. Il s’agit de la machine dont le nom est **Client\_In\_LAN**. (il est très facile de rajouter de machines supplémentaires sur le LAN utilisant Docker).

La **DMZ** est un réseau réservé aux serveurs que l'on veut rendre accessibles depuis l'extérieur et l’intérieur de notre réseau. Par exemple, si nous voulons publier un site web que l'on héberge, il faut accepter des connexions sur le serveur web; dans ce cas, nous ne pouvons pas le placer dans le LAN, cela constituerait un risque. Nous accepterons donc les connexions entrantes dans la DMZ, mais seulement pour les services que l'on désire offrir. Le serveur Web situé dans la DMZ est simulé par la machine **Server\_In\_DMZ**.

Le **WAN** n'est que l'accès à Internet. Il est connecté au réseau de l'école ou à votre propre à travers le système de réseau fourni par Docker.

Pour établir la table de filtrage, voici les **conditions à respecter** dans le cadre de ce laboratoire :

1.	Les **serveurs DNS** utilisés par les postes dans le LAN sont situés sur le WAN. Les services DNS utilisent les ports UDP 53 et TCP 53.
2.	Laisser passer les **PING** uniquement du LAN au WAN et du LAN à la DMZ. La DMZ ne doit pas pouvoir contacter le LAN. Le ping utilise le protocole ICMP (echo request et echo reply).
3.	Les clients du **LAN** doivent pouvoir ouvrir des connexions HTTP pour accéder au web. Le protocole HTTP utilise les ports TCP 80 et typiquement aussi le 8080.
4.	Les clients du **LAN** doivent pouvoir ouvrir des connexions HTTPS pour accéder au web. Le protocole HTTPS utilise le port TCP 443.
5.	Le serveur **web en DMZ** doit être atteignable par le WAN et le LAN et n'utilise que le port 80.
6.	Le serveur de la DMZ peut être commandé à distance par **ssh** depuis votre client du LAN **uniquement**. Le service ssh utilise le port TCP 22.
7.	Le firewall peut être configuré à distance par **ssh** depuis votre client du LAN **uniquement**.
8.	**Toute autre action est par défaut interdite**.

# Regles de filtrage

a) En suivant la méthodologie vue en classe, établir la table de filtrage avec précision en spécifiant la source et la destination, le type de trafic (TCP/UDP/ICMP/any), les ports sources et destinations ainsi que l'action désirée (<b>Accept</b> ou <b>Drop</b>, éventuellement <b>Reject</b>).
  Pour cette partie, écrivez les règles en prenant en compte que vous allez mettre en place un Firewall <b>stateless</b>.

_Pour l'autorisation d'accès (**Accept**), il s'agit d'être le plus précis possible lors de la définition de la source et la destination : si l'accès ne concerne qu'une seule machine (ou un groupe), il faut préciser son adresse IP ou son nom (si vous ne pouvez pas encore la déterminer), et non la zone.
Appliquer le principe inverse (être le plus large possible) lorsqu'il faut refuser (**Drop**) une connexion._

_Lors de la définition d'une zone, spécifier l'adresse du sous-réseau IP avec son masque (par exemple, "/24" correspond à 255.255.255.0) ou l'interface réseau (par exemple : "interface WAN") si l'adresse du sous-réseau ne peut pas être déterminée avec précision._

---

**LIVRABLE : Remplir le tableau**

| Adresse IP source                | Adresse IP destination           | Type | Port src | Port dst | Action  |
|----------------------------------|----------------------------------|------|----------|----------|---------|
| LAN (192.168.100.0/24)           | WAN (Dynamic)                    | TCP  | *        | 53       | Accept  |
| LAN (192.168.100.0/24)           | WAN (Dynamic)                    | UDP  | *        | 53       | Accept  |
| LAN (192.168.100.0/24)           | WAN (Dynamic)                    | ICMP | *        | *        | Accept  |
| LAN (192.168.100.0/24)           | DMZ (192.168.200.0/24)           | ICMP | *        | *        | Accept  |
| LAN (192.168.100.0/24)           | WAN (Dynamic)                    | TCP  | *        | 80, 8080 | Accept  |
| LAN (192.168.100.0/24)           | WAN (Dynamic)                    | TCP  | *        | 443      | Accept  |
| LAN (192.168.100.0/24)           | DMZ (192.168.200.3)              | TCP  | *        | 80       | Accept  |
| Client\_In\_LAN (192.168.100.3)  | Server\_In\_DMZ (192.168.200.3)  | TCP  | *        | 22       | Accept  |
| Client\_In\_LAN (192.168.100.3)  | Firewall (192.168.100.2)         | TCP  | *        | 22       | Accept  |
| *                                | *                                | *    | *        | *        | Drop    |

---

# Installation de l’environnement virtualisé

Ce chapitre indique comment installer l'environnement. Il se base sur des outils gratuits, téléchargeables sur Internet.

## Matériel
Il est possible d’utiliser les mêmes instructions sur une version de Windows ou un système Linux ou Mac OS X.

Afin d'installer les différents logiciels présentés ici, il faut disposer d’un ordinateur (avec les droits administrateur).

## Installation de Docker
Docker est un logiciel permettant de créer des conteneurs virtuels afin de simuler diverses configurations. Nous l'utiliserons pour exécuter les trois machines dont nous aurons besoin pour ce laboratoire. L’installation de Docker ne comporte pas de difficulté particulière. Une installation « par défaut » suffira. Il est possible d’utiliser une version que vous avez déjà installée ou une version téléchargée, mais la documentation pour ce laboratoire a été testée avec la version 3.2.2 de Docker Desktop pour Mac. Si vous rencontrez des problèmes, une mise à jour de Docker es peut-être la solution.

Vous pouvez trouver Docker pour Windows et Mac OS [ici](https://www.docker.com/products/docker-desktop).

Pour Linux, referez-vous au gestionnaire de paquets de votre distribution.

## Installation de Git

Vous avez probablement déjà installé Git pour d’autres cours ou projets. Si ce n’est pas le cas, vous pouvez prendre la bonne version pour votre OS [ici](https://git-scm.com/download/).


## Démarrage de l'environnement virtuel

### Ce laboratoire utilise docker-compose, un outil pour la gestion d'applications utilisant multiples conteneurs. Il va se charger de créer les réseaux `lan` et `dmz`, la machine Firewall, un serveur dans le réseau DMZ et une machine dans le réseau LAN et de tout interconnecter correctement.

Nous allons commencer par lancer docker-compose. Il suffit de taper la commande suivante dans le répertoire racine du labo (celui qui contient le fichier `docker-compose.yml`:

```bash
docker-compose up --detach
```
Le téléchargement et génération d'images prend peu de temps.

Vous pouvez vérifier que les réseaux ont été créés avec la commande `docker network ls`. Un réseau `lan` et un réseau `dmz` devraient se trouver dans la liste. Lors de la création d'un network, docker utilise l'adresse *x.x.x.1* comme gateway entre l'hôte et le network correspondant. C'est pourquoi vous verrez que les adresses IP des interfaces réseau de la machine *firewall* sont en *x.x.x.2*. Vous trouverez les interfaces réseau virtuelles créées par docker pour communiquer avec les différents réseau en utilisant la command *ip address*; les interfaces en question se nomment *br-NETWORK ID*.

Les images utilisées pour les conteneurs sont basées sur l'image officielle Ubuntu. Le fichier `Dockerfile` que vous avez téléchargé contient les informations nécessaires pour la génération de l'image de base. `docker-compose` l'utilise comme un modèle pour générer les conteneurs. Vous pouvez vérifier que les trois conteneurs sont crées et qu'ils fonctionnent à l'aide de la commande suivante:

```bash
docker-compose ps
```

Pour que ça marche, vous devez être dans le répertoire où se trouve le docker-compose.yaml.

## Communication avec les conteneurs et configuration du firewall

Afin de simplifier vos manipulations, les conteneurs ont été configurées avec les noms suivants :

- firewall
- client\_in\_lan
- server\_in\_dmz

Pour accéder au terminal de l’une des machines, il suffit de taper :

```bash
docker-compose exec <nom_de_la_machine> /bin/bash
```
ou pour une installation docker plus moderne:
```bash
docker compose exec <nom_de_la_machine> /bin/bash
```

Par exemple, pour ouvrir un terminal sur votre firewall :

```bash
docker-compose exec firewall /bin/bash
```
ou pour une installation docker plus moderne:
```bash
docker compose exec firewall /bin/bash
```

Vous pouvez bien évidemment lancer des terminaux avec les trois machines en même temps, ou utiliser 
le "Docker Desktop" pour lancer les terminaux.


## Configuration de base

La plupart de paramètres sont déjà configurés correctement sur les trois machines. Il est pourtant nécessaire de rajouter quelques commandes afin de configurer correctement le réseau pour le labo.

Vous pouvez commencer par vérifier que le ping n'est pas possible actuellement entre les machines. Depuis votre Client\_in\_LAN, essayez de faire un ping sur le Server\_in\_DMZ (cela ne devrait pas fonctionner !) :

```bash
ping 192.168.200.3
```
---

**LIVRABLE : copié/collé de votre tentative de ping.**  

On voit que le ping ne passe pas.

![image](https://hackmd.io/_uploads/r1W9TMDa6.png)

---

En effet, la communication entre les clients dans le LAN et les serveurs dans la DMZ doit passer à travers le Firewall. Dans certaines configurations, il est probable que le ping arrive à passer par le bridge par défaut. Ceci est une limitation de Docker. **Si votre ping passe**, vous pouvez accompagner votre capture du ping avec une capture d'une commande traceroute qui montre que le ping ne passe pas actuellement par le Firewall mais qu'il a emprunté un autre chemin.

Il faut donc définir le Firewall comme passerelle par défaut pour le client dans le LAN et le serveur dans la DMZ.

### Configuration du client LAN

Dans un terminal de votre client, taper les commandes suivantes :

```bash
ip route del default
ip route add default via 192.168.100.2
```

### Configuration du serveur dans la DMZ

Dans un terminal de votre serveur dans DMZ, taper les commandes suivantes :

```bash
ip route del default
ip route add default via 192.168.200.2

service nginx start
service ssh start
```

Les deux dernières commandes démarrent les services Web et SSH du serveur.

La communication devrait maintenant être possible entre les deux machines à travers le Firewall. Faites un nouveau test de ping, cette fois-ci depuis le serveur vers le client :

```bash
ping 192.168.100.3
```

---

**LIVRABLES : copié/collé des routes des deux machines et de votre nouvelle tentative de ping.**


![image](https://hackmd.io/_uploads/S1ISszva6.png)

---

La communication est maintenant possible entre les deux machines. Pourtant, si vous essayez de communiquer depuis le client ou le serveur vers l'Internet, ça ne devrait pas encore fonctionner sans une manipulation supplémentaire au niveau du firewall ou sans un service de redirection ICMP. Vous pouvez le vérifier avec un ping depuis le client ou le serveur vers une adresse Internet.

Par exemple :

```bash
ping 8.8.8.8
```





Si votre ping passe mais que la réponse contient un _Redirect Host_, ceci indique que votre ping est passé grâce à la redirection ICMP, mais que vous n'arrivez pas encore à contacter l'Internet à travers le Firewall. Ceci est donc aussi valable pour l'instant et accepté comme résultat.


On voit que le ping ne passe pas come prévu.

<pre>root@server_in_dmz:/# ping 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
^C
--- 8.8.8.8 ping statistics ---
11 packets transmitted, 0 received, 100% packet loss, time 10217ms
</pre>
---

**LIVRABLE : copié/collé de votre ping vers l'Internet. Un ping qui ne passe pas ou des réponses contenant des _Redirect Host_ sont acceptés.**

---

### Configuration réseau du firewall

On va fournir une route vers l'internet à travers le firewall aux deux réseaux connectés. Pour cela, on va se servir des premières commandes `nftables` :

```bash
nft add table fw_nat
nft 'add chain fw_nat postrouting { type nat hook postrouting priority 100 ; }'
nft add rule fw_nat postrouting meta oifname "eth0" masquerade
```

La dernière commande `nftables` définit une règle dans le tableau NAT qui permet la redirection de ports et donc, l'accès à l'Internet pour les deux autres machines à travers l'interface eth0 qui est connectée au WAN.


b) Quelle est l'utilité de la première commande ?


---

**Réponse :** La première commande `nft add table fw_nat` crée une nouvelle table appelée `fw_nat` dans `nftables`. Les tables permettent de grouper des ensembles de règles. Dans ce cas, cette table sera utilisée pour la configuration NAT (Network Address Translation), essentielle pour masquer les adresses IP internes et permettre le trafic sortant vers Internet.

---

c) Quelle est l'utilité de la deuxième commande ? Expliquer chacun des paramètres.

---

**Réponse :** La deuxième commande crée une chaîne dans la table précédemment créée avec la commande spécifiée. Voici une décomposition des paramètres :
- `add chain fw_nat postrouting`: Ajoute une chaîne nommée `postrouting` à la table `fw_nat`. Cette chaîne est utilisée pour des règles appliquées après que le routage est décidé, typiquement pour le NAT.
- `{ type nat hook postrouting priority 100 ; }`: Spécifie que la chaîne est de type NAT et qu'elle s'accroche au point `postrouting` (après le routage). La priorité `100` détermine l'ordre d'exécution par rapport à d'autres chaînes éventuelles.
- Cette configuration permet au firewall de modifier les paquets sortants (par exemple, pour le masquage d'adresse), après que la décision de routage a été prise mais avant que les paquets ne quittent le firewall.

---


Cette autre commande démarre le service SSH du serveur :

```bash
service ssh start
```

Vérifiez que la connexion à l'Internet est maintenant possible depuis les deux autres machines ou qu'elle n'utilise plus de reditection. Pas besoin de capture d'écran mais assurez vous que les pings passent sans besoin de redirection de host avant de continuer.


# Manipulations

## Création de règles

Une règle permet d’autoriser ou d’interdire une connexion. `nftables` met à disposition plusieurs options pour la création de ces règles. En particulier, on peut définir les politiques par défaut, des règles de filtrage pour le firewall ou des fonctionnalités de translation d’adresses (nat). **Vous devriez configurer vos politiques en premier.**

`nftables` vous permet la configuration de pare-feux avec et sans état. **Pour ce laboratoire, vous devez commencer par utiliser le mode sans état. Puis à partir de l'étape *Règles pour le protocole DNS*, vous devez utiliser le mode avec état.**

Chaque règle doit être tapée sur une ligne séparée. Référez-vous à la théorie et appuyez-vous sur des informations trouvées sur Internet pour traduire votre tableau de règles de filtrage en commandes `nftables`. Les règles prennent effet immédiatement après avoir appuyé sur \<enter\>. Vous pouvez donc les tester au fur et à mesure que vous les configurez.


## Sauvegarde et récupération des règles

**Important** : Les règles de filtrage définies avec `nftables` ne sont pas persistantes (par défaut, elles sont perdues après chaque redémarrage de la machine firewall). Il existe pourtant de manières de sauvegarder votre config.

d) Faire une recherche et expliquer une méthode de rendre la config de votre firewall persistente.

---

**Réponse :** Pour rendre la configuration de `nftables` persistante, c'est-à-dire pour qu'elle survive aux redémarrages du système, vous pouvez utiliser la commande `nft list ruleset > /etc/nftables.conf` pour sauvegarder les règles actuelles dans un fichier de configuration. Ce fichier sera ensuite lu et appliqué au démarrage du système. Sur la plupart des distributions Linux, le service `nftables` est configuré pour charger les règles depuis ce fichier lors du démarrage.

<pre>root@firewall:/etc# cat nftables.conf 
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
	chain input {
		type filter hook input priority 0;
	}
	chain forward {
		type filter hook forward priority 0;
	}
	chain output {
		type filter hook output priority 0;
	}
}
table inet fw_nat {
    chain postrouting {
        type nat hook postrouting priority 100;
        oifname &quot;eth0&quot; masquerade
    }
}
</pre>

---


&rarr; Note : Puisque vous travaillez depuis un terminal natif de votre machin hôte, vous pouvez facilement copier/coller les règles dans un fichier local. Vous pouvez ensuite les utiliser pour reconfigurer votre firewall en cas de besoin.


e) Quelle commande affiche toutes les règles de filtrage en vigueur ?

---

**Réponse :** `nft list ruleset`

---


f) Quelle commande est utilisée pour effacer toutes les règles de filtrage en vigueur ?

---

**Réponse :** `nft flush ruleset`

---


g) Quelle commande est utilisée pour effacer les chaines ?

---

**Réponse :** `nft delete chain [family] <table> <chain>`

---


---

## Tests des connections et exemple de l'application d'une règle

Pour chaque manipulation, il est important de **garder les règles déjà créées**, les nouvelles sont ajoutées aux existantes.

Pour commencer sur une base fonctionnelle, nous allons configurer le pare-feu pour accepter le **ping** dans certains cas. Cela va permettre de tester la connectivité du réseau.

Le but est de configurer les règles pour que le pare-feu accepte
-	les ping depuis le LAN sur les machines de la DMZ,
-	les ping depuis le LAN sur le WAN,

Ceci correspond a la **condition 2** du cahier des charges.

Commandes nftables :

---

```bash
LIVRABLE : 
# Création de la table de filtrage principale
nft add table filter

# Création des chaines de filtrage pour le trafic entrant, sortant et transitant
nft add chain ip filter forward { type filter hook forward priority 0 \; policy drop\;}
nft add chain ip filter input { type filter hook input priority 0 \; policy drop\;}     
nft add chain ip filter output { type filter hook output priority 0 \; policy drop\;}

# Autoriser les requêtes ICMP (ping) du LAN vers la DMZ et le WAN
nft add rule filter forward ip saddr 192.168.100.0/24 oifname "eth0" icmp type echo-request accept
nft add rule filter forward ip daddr 192.168.100.0/24 iifname "eth0" icmp type echo-reply accept
nft add rule filter forward ip saddr 192.168.100.0/24 ip daddr 192.168.200.0/24 icmp type echo-request accept
nft add rule filter forward ip saddr 192.168.200.0/24 ip daddr 192.168.100.0/24 icmp type echo-reply accept 


```
**Firewall tables** 

<pre>nft list ruleset
table ip filter {
	chain forward {
		type filter hook forward priority filter; policy drop;
		ip saddr 192.168.100.0/24 oifname &quot;eth0&quot; icmp type echo-request accept
		ip daddr 192.168.100.0/24 iifname &quot;eth0&quot; icmp type echo-reply accept
		ip saddr 192.168.100.0/24 ip daddr 192.168.200.0/24 icmp type echo-request accept
		ip saddr 192.168.200.0/24 ip daddr 192.168.100.0/24 icmp type echo-reply accept
	}

	chain input {
		type filter hook input priority filter; policy drop;
	}

	chain output {
		type filter hook output priority filter; policy drop;
	}
}
table ip fw_nat {
	chain postrouting {
		type nat hook postrouting priority srcnat; policy accept;
		oifname &quot;eth0&quot; masquerade
	}
}
</pre>

---

### Questions

h) Afin de tester la connexion entre le client (Client_in_LAN) et le WAN, tapez la commande suivante depuis le client :


```bash
ping 8.8.8.8
``` 	            
Faire une capture du ping.

<pre>root@client_in_lan:/# ping 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=253 time=8.85 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=253 time=7.04 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=253 time=9.18 ms
^C
--- 8.8.8.8 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2004ms
rtt min/avg/max/mdev = 7.035/8.353/9.178/0.942 ms
</pre>

Vérifiez aussi la route entre votre client et le service `8.8.8.8`. Elle devrait partir de votre client et traverser votre Firewall :

```bash
traceroute -I 8.8.8.8
``` 	            


---
**LIVRABLE : copié/collé du traceroute et de votre ping vers l'Internet. Il ne devrait pas y avoir des _Redirect Host_ dans les réponses au ping !**

<pre>root@client_in_lan:/# traceroute -I 8.8.8.8
traceroute to 8.8.8.8 (8.8.8.8), 30 hops max, 60 byte packets
 1  labo-2-firewall-lab2_rayburn_harun-firewall-1.1lan (192.168.100.2)  1.658 ms  1.513 ms  1.478 ms
 2  * * *
 3  8.8.8.8 (8.8.8.8)  8.473 ms  8.901 ms  8.767 ms
</pre>

---

i) Analysez le résultat de la commande traceroute. Que se passe-t-il lors du premier saut ?

---

**Réponse :** Le firewall filtre le paquet parce qu'il reçoit un time exceeded qui ne fait pas parti du echo reply. Vu que le TTL est à 0, le paquet sera ignoré.

---

j) Testez ensuite toutes les règles, depuis le Client_in_LAN puis depuis le serveur Web (Server_in_DMZ) et remplir le tableau suivant :


| De Client\_in\_LAN à | OK/KO | Commentaires et explications |
| :---                 | :---: | :---                         |
| Interface DMZ du FW  |   OK  |forward fait par le FW|
| Interface LAN du FW  |   OK  |Dans le même sous réseau|
| Serveur DMZ          |   OK  |forward fait par le FW|
| Serveur WAN          |   OK  |Table de fw_nat|


| De Server\_in\_DMZ à | OK/KO | Commentaires et explications |
| :---                 | :---: | :---                         |
| Interface DMZ du FW  |   OK   |On est dans le même sous réseau|
| Interface LAN du FW  |   OK   | |
| Client LAN           |   KO   |DMZ vers LAN refusé|
| Serveur WAN          |   KO   |DMZ vers WAN refusé|


## Règles pour le protocole DNS

k) Si un ping est effectué sur un serveur externe en utilisant en argument un nom DNS, le client ne pourra pas le résoudre. Le démontrer à l'aide d'une capture, par exemple avec la commande suivante :

```bash
ping www.google.com
```

* Faire une capture du ping.

---

**LIVRABLE : copié/collé de votre ping.**

<pre>root@client_in_lan:/# ping www.google.com
ping: www.google.com: Temporary failure in name resolution
</pre>

---

* Créer et appliquer la règle adéquate pour que la **condition 1 du cahier des charges** soit respectée.

Commandes nftables :

---

```bash
LIVRABLE : Commandes nftables

# Autoriser les requêtes DNS TCP sortantes du LAN vers le WAN
nft add rule ip filter forward ip saddr 192.168.100.0/24 oifname "eth0" tcp dport 53 ct state new,established accept

# Autoriser les réponses DNS TCP entrantes du WAN vers le LAN
nft add rule ip filter forward ip daddr 192.168.100.0/24 iifname "eth0" tcp sport 53 ct state established accept

# Autoriser les requêtes DNS UDP sortantes du LAN vers le WAN
nft add rule ip filter forward ip saddr 192.168.100.0/24 oifname "eth0" udp dport 53 ct state new,established accept

# Autoriser les réponses DNS UDP entrantes du WAN vers le LAN
nft add rule ip filter forward ip daddr 192.168.100.0/24 iifname "eth0" udp sport 53 ct state established accept
```

---

l) Tester en réitérant la commande ping sur le serveur de test (Google ou autre) :

<pre>root@client_in_lan:/# ping www.google.com
PING www.google.com (142.250.203.100) 56(84) bytes of data.
64 bytes from 142.250.203.100 (142.250.203.100): icmp_seq=1 ttl=253 time=6.73 ms
64 bytes from 142.250.203.100 (142.250.203.100): icmp_seq=2 ttl=253 time=8.72 ms
64 bytes from 142.250.203.100 (142.250.203.100): icmp_seq=3 ttl=253 time=10.7 ms
64 bytes from 142.250.203.100 (142.250.203.100): icmp_seq=4 ttl=253 time=8.36 ms
</pre>

---

**LIVRABLE : copié/collé de votre ping.**

---

m) Remarques (sur le message du premier ping)?

---
**Réponse**

**Le port 53 n'était pas ouvert donc on ne pouvait pas résoudre le domain name par le serveur DNS.**

---


## Règles pour les protocoles HTTP et HTTPS

Créer et appliquer les règles adéquates pour que les **conditions 3 et 4 du cahier des charges** soient respectées. Tester que les règles soient fonctionnelles en utilisant wget depuis le Client\_in\_LAN pour télécharger une ressource depuis un site Web de votre choix (sur le WAN). Par exemple :

```bash
curl https://srx-lab2.fledg.re/
```

* Créer et appliquer les règles adéquates avec des commandes nftables.

Commandes nftables :

---

```bash
# Autoriser le trafic HTTP, HTTPS sortant du LAN
nft add rule ip filter forward ip saddr 192.168.100.0/24 oifname "eth0" tcp dport { 80, 443, 8080 } ct state new,established accept

# Autoriser le trafic HTTP, HTTPS entrant vers le LAN
nft add rule ip filter forward ip daddr 192.168.100.0/24 iifname "eth0" tcp sport { 80, 443, 8080 } ct state established accept
```

---

* Créer et appliquer les règles adéquates avec des commandes nftables pour que la **condition 5 du cahier des charges** soit respectée.

Commandes nftables :

---

```bash
# Autoriser le trafic HTTP du LAN vers le serveur en DMZ
nft add rule ip filter forward ip saddr 192.168.100.0/24 ip daddr 192.168.200.3 tcp dport 80 ct state new,established accept

# Autoriser le trafic HTTP du serveur en DMZ vers le LAN
nft add rule ip filter forward ip daddr 192.168.100.0/24 ip saddr 192.168.200.3 tcp sport 80 ct state established accept

# Autoriser le serveur en DMZ à initier du trafic HTTP vers l'extérieur
nft add rule ip filter forward ip saddr 192.168.200.3 oifname "eth0" tcp dport 80 ct state new,established accept

# Autoriser les réponses au trafic HTTP initié par le serveur en DMZ
nft add rule ip filter forward ip daddr 192.168.200.3 iifname "eth0" tcp sport 80 ct state established accept

```
---

n) Tester l’accès à ce serveur depuis le LAN utilisant utilisant wget (ne pas oublier les captures d'écran).

---

<pre>root@client_in_lan:/# wget https://www.heig-vd.ch
--2024-03-19 20:06:15--  https://www.heig-vd.ch/
Resolving www.heig-vd.ch (www.heig-vd.ch)... ::ffff:193.134.223.20, 193.134.223.20
Connecting to www.heig-vd.ch (www.heig-vd.ch)|::ffff:193.134.223.20|:443... ^C
root@client_in_lan:/# wget https://www.heig-vd.ch
--2024-03-19 20:06:50--  https://www.heig-vd.ch/
Resolving www.heig-vd.ch (www.heig-vd.ch)... 193.134.223.20, ::ffff:193.134.223.20
Connecting to www.heig-vd.ch (www.heig-vd.ch)|193.134.223.20|:443... connected.
HTTP request sent, awaiting response... 301 Moved Permanently
Location: https://heig-vd.ch/ [following]
--2024-03-19 20:06:50--  https://heig-vd.ch/
Resolving heig-vd.ch (heig-vd.ch)... 193.134.223.20, ::ffff:193.134.223.20
Connecting to heig-vd.ch (heig-vd.ch)|193.134.223.20|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 58457 (57K) [text/html]
Saving to: &apos;index.html&apos;

index.html                 100%[=====================================&gt;]  57.09K  --.-KB/s    in 0.01s   

2024-03-19 20:06:51 (5.39 MB/s) - &apos;index.html&apos; saved [58457/58457]
</pre>

![image](https://hackmd.io/_uploads/Bku2e_vA6.png)


---


## Règles pour le protocole ssh

o) Créer et appliquer la règle adéquate pour que les <b>conditions 6 et 7 du cahier des charges</b> soient respectées.

Commandes nftables :

---

```bash
LIVRABLE : Commandes nftables

# LAN VERS DMZ
nft add rule ip filter forward ip saddr 192.168.100.3 ip daddr 192.168.200.3 tcp dport 22 ct state new,established accept

nft add rule ip filter forward ip daddr 192.168.100.3 ip saddr 192.168.200.3 tcp sport 22 ct state established accept

# LAN VERS FW
nft add rule ip filter input ip saddr 192.168.100.3 ip daddr 192.168.100.2 tcp dport 22 ct state new,established accept

nft add rule ip filter output ip daddr 192.168.100.3 ip saddr 192.168.100.2 tcp sport 22 ct state established accept


```

---

Depuis le client dans le LAN, tester l’accès avec la commande suivante :

```bash
ssh 192.168.200.3
```

---

<pre>root@client_in_lan:/# ssh 192.168.200.3
The authenticity of host &apos;192.168.200.3 (192.168.200.3)&apos; can&apos;t be established.
ED25519 key fingerprint is SHA256:gYX+3eMp169RwIBruydcLPHZQdaBRbqeAN5kR3yXBhE.
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added &apos;192.168.200.3&apos; (ED25519) to the list of known hosts.
Welcome to Ubuntu 22.04.4 LTS (GNU/Linux 6.6.16-linuxkit x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/pro

This system has been minimized by removing packages and content that are
not required on a system that users do not log into.

To restore this content, you can run the &apos;unminimize&apos; command.

The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.
root@server_in_dmz:~# 
</pre>

---

p) Expliquer l'utilité de <b>ssh</b> sur un serveur. 
Bonus: expliquez comment les trois machines se font confiance pour les connections ssh.

---
**Réponse :**


SSH est essentiel pour la gestion sécurisée des serveurs, offrant un accès crypté pour l'exécution de commandes et la maintenance à distance. Il permet un transfert de fichiers sécurisé via SCP ou SFTP et supporte le tunneling pour sécuriser d'autres communications. L'authentification par clés offre une sécurité supérieure aux mots de passe, limitant l'accès aux utilisateurs autorisés.


La confiance entre les machines pour les connexions SSH est fondée sur l'échange et la reconnaissance de clés publiques et privées. Voici le processus général :

**Placement de la clé publique :** Un utilisateur génère une paire de clés (publique et privée) et place la clé publique sur le serveur (ou les serveurs) auquel il souhaite se connecter. Cette clé publique est ajoutée au fichier `/root/.ssh/authorized_keys` sur le serveur.

**Authentification :** Lorsqu'une tentative de connexion SSH est initiée, le serveur vérifie si le client possède la clé privée correspondant à l'une des clés publiques stockées dans le fichier /root/.ssh/authorized_keys. Le serveur demande alors au client de prouver qu'il détient cette clé privée.

**Établissement de la session SSH :** Si le client peut prouver la possession de la clé privée correspondante, l'accès est accordé et une session SSH sécurisée est établie.

 
Dans le contexte du laboratoire, avec les Dockerfile inspectés, il est révélé que toutes les machines (conteneurs) partagent les mêmes paires de clés publiques/privées, stockées dans `/root/.ssh/`. Chaque machine authorise la clé publique dans `root/.ssh/authorized_keys`. Ce qui permet à une autre machine qui a la bonne clé privée et d'établir une connexion sécurisée. Comme toutes les machines ont cette configuration particulière, simplifie l'établissement de la confiance mutuelle entre les trois machines.

---

q) En général, à quoi faut-il particulièrement faire attention lors de l'écriture des règles du pare-feu pour ce type de connexion ?


---
**Réponse:**


**Restriction d'adresse IP** : Limitez l'accès SSH aux seules adresses IP nécessaires pour réduire la surface d'attaque. Évitez d'autoriser l'accès SSH depuis n'importe quelle adresse IP.

**Port SSH non standard** : Envisagez de changer le port par défaut (22) pour un port non standard afin de diminuer le risque d'attaques automatisées.

**Taux de connexion** : Appliquez des règles limitant le nombre de tentatives de connexion SSH échouées sur une période donnée pour prévenir les attaques bruteforce.

---

## Règles finales

A présent, vous devriez avoir le matériel nécessaire afin de reproduire la table de filtrage que vous avez conçue au début de ce laboratoire.

r) Insérer la capture d’écran avec toutes vos règles nftables

---

**LIVRABLE : copié/collé avec toutes vos règles.**

![image](https://hackmd.io/_uploads/rJ2uQyFA6.png)

---

# Flag pour cette session

Il y a de nouveau un flag caché quelque part dans le labo.
Je cherche encore la difficulté convenable, donc pour cette fois-ci vous devez utiliser quelque chose dont j'ai parlé que brièvement pendant le cours.
Le flag est quelque part en ASCII et se présente comme ça:

```
Flag SRX-2024-####
```

Où le `####` est un code aléatoire de 16 chiffres hexadécimales.

# Création automatique du docker

Ce répositoire contient un github-workflow pour la création automatique des images docker.
Pour que ça marche, il faut que l'organisation soit configuré correctement:
- aller sur la page de l'organisation
- Settings en haut à droite
- Actions - General à gauche
- tout en bas, `Workflow permissions` sur `Read and Write permissions`
