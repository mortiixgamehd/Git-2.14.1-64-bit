-- SQL schema pour la ressource eboueur
-- Tables : zones personnalisées et progression joueur

-- Table pour stocker les zones personnalisées (JSON)
CREATE TABLE IF NOT EXISTS `eboueur_zones` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `name` varchar(128) NOT NULL UNIQUE,
  `data` longtext NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Table pour stocker l'XP / level des joueurs
CREATE TABLE IF NOT EXISTS `eboueur_players` (
  `identifier` varchar(64) NOT NULL, -- steam:hex, license or identifier
  `xp` int(11) NOT NULL DEFAULT 0,
  `level` int(11) NOT NULL DEFAULT 1,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Indexes utiles
CREATE INDEX IF NOT EXISTS `idx_eboueur_zones_name` ON `eboueur_zones`(`name`(64));
CREATE INDEX IF NOT EXISTS `idx_eboueur_players_identifier` ON `eboueur_players`(`identifier`(32));
