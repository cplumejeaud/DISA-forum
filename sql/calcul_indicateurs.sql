---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Auteur : Christine Plumejeaud-Perreau
-- 			UMR LIENSs 7266, CNRS et Université de la Rochelle, 
-- 			christine.plumejeaud-perreau@univ-lr.fr
-- Objet : Calcul d'indicateurs (descripteurs) sur les zones humides, pour le Forum des Marais, 
-- Mise à jour : 10, 11, 12 mai 2017 - 23 puis 26 Juin 2017 - puis le 10 et 11 novembre 2017
-- Ce fichier permet de suivre les étapes de calcul des indicateurs, mais il ne doit pas être exécuté directement depuis psql. 
-- 		   
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------
-- Déport des calculs sur MAPUCE.in2p3.fr
------------------------------------------------------------------------------------------------------

--- Procédure de restauration en tant que sudoer plumegeo sur la machine


-- sur mapuce
sudo adduser forum
sudo adduser forum users
sudo adduser postgres forum 

--- Pour créer la BD
sudo -u postgres createdb forum
sudo -u postgres psql -d forum
create extension postgis;
create extension postgis_topology;


cd /home/plumegeo/forum

-- Set .pgpass pour ne pas avoir à taper le mot de passe postgres (mode script avec nohup)
-- Doc sur : http://docs.postgresqlfr.org/8.1/libpq-pgpass.html
vi ~/.pgpass
localhost:5432:forum:postgres:xxxxxx 
chmod 0600 ~/.pgpass

-- autre méthode, moins propre ni sécurisée : PGPASSWORD
export PGPASSWORD="xxxxxx"

-- Pour restaurer la BD
pg_restore -w -U postgres -d forum  /home/forum/inventaires_20170505.backup

-- Pour tester le mode script
nohup psql -U postgres -d forum -c "select 4" > out.txt  &



---------------------------------------------------------------------------------------------------
-- Création du schéma indicateurs
---------------------------------------------------------------------------------------------------

-- Exécuter sur la base forum le script fourni
psql -U postgres -d forum -f /home/forum/Dump\ tables\ FMA/lienss_2016_06_16.sql
 
 
set search_path = indicateurs, fma, referentiels, public;

-- L'ensembles des zoone_humides suivantes (liste des gid) a été repéré comme invalide pour ces géométries. 
-- On les exclut de tout calcul impliquant des manips de géométries
-- zhu.gid not in (405007,405235,405812,406312,406589,406641,2286180,2375241,4903324,4906542) 

-- Mettre à jour les index
vacuum analyze;

---------------------------------------------------------------------------------------------------
-- Création d'un masque de test 
---------------------------------------------------------------------------------------------------


-- import d'une table masque_test
-- shp2pgsql -c -I /home/forum/donnees/masque indicateurs.masque_test | psql -d forum -U postgres
/home/forum/donnees/masque
alter table indicateurs.masque_test alter column geom type geometry(Polygon) ;
update indicateurs.masque_test set geom = st_setsrid(geom, 4326)
update indicateurs.masque_test set geom = st_setsrid(st_transform(geom, 2154), 2154)
select st_astext(geom) from indicateurs.masque_test
select st_srid(geom) from indicateurs.masque_test  masque;
-- 2154



------------------------------------------------------------------------------------------------------------------------
-- Mise à jour de la table fma.zone_humide avec l'identifiant de la zone hydro intersectée (surface majoritaire)
------------------------------------------------------------------------------------------------------------------------

alter table fma.zone_humide add column zhy_gid integer;
COMMENT ON COLUMN  fma.zone_humide.zhy_gid IS 'identifiant de la zone hydro d''appartenance (schema referentiels), surface majoritaire, FK';


update fma.zone_humide f set zhy_gid=z.zhy_gid from public.zone_humide z where z.gid = f.gid
-- Query returned successfully: 572004 rows affected, 01:48 minutes execution time.

-------------------------------------------------------------------------------------------------------------------------
-- Indicateur 1 / A1 - natura_2000 
-------------------------------------------------------------------------------------------------------------------------

--- 23 06 2017. Import des SIC données par FMA
-- /home/forum/donnees/inpn/natura2000
ogr2ogr -f "PostgreSQL" PG:"host=localhost port=5432 user=postgres dbname=forum password=******* schemas=referentiels"  /home/forum/donnees/inpn/natura2000/sic.shp -nlt PROMOTE_TO_MULTI -a_srs "EPSG:2154"


/* ce qui génère  : 

CREATE TABLE referentiels.sic
(
  ogc_fid serial NOT NULL,
  wkb_geometry geometry(MultiPolygon,2154),
  sitecode character varying(9),
  sitename character varying(160),
  CONSTRAINT sic_pkey PRIMARY KEY (ogc_fid)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE referentiels.sic
  OWNER TO postgres;

-- Index: referentiels.sic_wkb_geometry_geom_idx

-- DROP INDEX referentiels.sic_wkb_geometry_geom_idx;

CREATE INDEX sic_wkb_geometry_geom_idx
  ON referentiels.sic
  USING gist
  (wkb_geometry);
*/
select ogc_fid, sitecode from referentiels.sic where st_isvalid(wkb_geometry) is false
64;"FR2100312"
131;"FR2300132"
192;"FR2500099"
357;"FR4201806"
361;"FR4201812"
227;"FR2600971"
326;"FR4100219"
390;"FR4301322"
397;"FR4301344"
583;"FR7200693"
605;"FR7200722"
651;"FR7200790"
1132;"FR4201797"
1271;"FR3100512"
1347;"FR8301091"
1305;"FR2500117"
1316;"FR4301306"
1338;"FR8201743"


select ogc_fid, sitecode from referentiels.sic where st_issimple(wkb_geometry) is false
-- 0

-- Tester
select 'A1', zhu.gid, st_intersects(zn.wkb_geometry, zhu.geom)::integer as note
from referentiels.sic zn, fma.zone_humide zhu
where zhu.gid not in (405007,405235,405812,406312,406589,406641,2286180,2375241,4903324,4906542) and st_intersects(zn.wkb_geometry, zhu.geom) 
-- 17 min 53 pour 66669 lignes

-- Metre à jour l'indicateur
update note i set i_brut = 1, missing = false 
from 
(select 'A1', zhu.gid
from referentiels.sic zn, fma.zone_humide zhu
where zhu.gid not in (405007,405235,405812,406312,406589,406641,2286180,2375241,4903324,4906542) 
and st_intersects(zn.wkb_geometry, zhu.geom)) as k
where code_ind = 'A1' and i.zhu_gid = k.gid ;  
-- Query returned successfully: 66424 rows affected, 08:30 minutes execution time.

update note i set i_brut = 0, missing = false 
where code_ind = 'A1' and i_brut is null;
-- Query returned successfully: 509212 rows affected, 23.3 secs execution time.

update note i set i_brut = null, missing = true 
where code_ind = 'A1' and zhu_gid in (405007,405235,405812,406312,406589,406641,2286180,2375241,4903324,4906542) ;
-- Query returned successfully: 10 rows affected, 19.9 secs execution time.

------------------------------------------------------------------------------------------------------
-- indicateur 2 - inpn_biotope
------------------------------------------------------------------------------------------------------


--- 23 06 2017. Import des INPN apb données par FMA
-- /home/forum/donnees/inpn/apb
-- ogr2ogr -f "PostgreSQL" PG:"host=localhost port=5432 user=postgres dbname=forum password=******* schemas=referentiels"  /home/forum/donnees/inpn/apb/apb.shp -nlt PROMOTE_TO_MULTI -a_srs "EPSG:2154"
-- failed : Unable to write feature 29 from layer apb...
shp2pgsql -c -I /home/forum/donnees/inpn/apb/apb.shp referentiels.apb | psql -d forum -U postgres

select distinct st_srid(geom) from referentiels.apb
-- 0

update referentiels.apb set geom = st_setsrid(geom, 2154);
--Query returned successfully: 828 rows affected, 375 msec execution time.


-- Metre à jour l'indicateur
update note i set i_brut = 1, missing = false 
from 
(select 'A3', zhu.gid
from referentiels.apb zn, fma.zone_humide zhu
where zhu.gid not in (405007,405235,405812,406312,406589,406641,2286180,2375241,4903324,4906542) 
and st_intersects(zn.geom, zhu.geom)) as k
where code_ind = 'A3' and i.zhu_gid = k.gid ;  
-- Query returned successfully: 3549 rows affected, 33.2 secs execution time.

update note i set i_brut = 0, missing = false 
where code_ind = 'A3' and i_brut is null;
-- Query returned successfully: 572087 rows affected, 22.6 secs execution time.

update note i set i_brut = null, missing = true 
where code_ind = 'A3' and zhu_gid in (405007,405235,405812,406312,406589,406641,2286180,2375241,4903324,4906542) ;
-- Query returned successfully: 10 rows affected, 19.9 secs execution time.


------------------------------------------------------------------------------------------------------
-- indicateur 15 - se_eaupot
------------------------------------------------------------------------------------------------------

/*
Dans la table fma.valeurs_socio_eco, on trouve ceci  : 
2;"Autres";" À préciser en remarque";1  -> B10
3;"Pas de valeur socio-économique identifiée";"";2 
4;"Production et stockage d'eau potable";"";3 -> B1
5;"Production biologique";" Aquaculture, pêche, chasse";4 -> B2
6;"Production agricole et sylvicole";" Pâturage, fauche, roseaux, sylviculture";5 -> B3
7;"Production de matière première";" Granulat, tourbe, sel, etc.";6 -> B4
8;"Intérêt pour la valorisation pédagogique/éducation";"";7 -> B5
9;"Paysage, patrimoine culturel, identité locale";"";8 -> B6
10;"(Intérêt pour les loisirs/valeurs récréatives)";"";9 -> B7
11;"Valeur scientifique";"";10 -> B8
14;"Tourisme";"''";11 -> B9

la ligne avec gid = 3 et vse_id = 4 correspond à Production et stockage d'eau potable. 
*/

select niv_libelle, count(zhu_vse_zhu) 
from fma.zhu_vse, fma.niveau 
where  niv_id=zhu_vse_imp and zhu_vse_vse = 4
group by niv_libelle
order by niv_libelle;

/*
"1";61957
"2";16826
"3";7974
*/

select * from fma.niveau;
/*
3;"1";1
4;"2";2
5;"3";3
*/



-- test
select zhu_vse_zhu, niv_libelle 
from fma.zhu_vse, fma.niveau 
where  niv_id=zhu_vse_imp
-- 86757
-- réinitialiser les valeurs pour cet indicateurs
update indicateurs.note i  set i_brut = null, missing = true  
where code_ind = 'B1'  ;
-- Query returned successfully: 575636 rows affected, 30.5 secs execution time.

-- Mettre à jour l'indicateur
update note i set i_brut = niveau, missing = false 
from 
(select 'B1', zhu_vse_zhu, niv_libelle::int as niveau
from fma.zhu_vse, fma.niveau
where niv_id=zhu_vse_imp and zhu_vse_vse = 4) as k
where code_ind = 'B1' and i.zhu_gid = k.zhu_vse_zhu ;  
-- Query returned successfully: 1196 rows affected, 19.5 secs execution time.


------------------------------------------------------------------------------------------------------
-- indicateur à créer B11
------------------------------------------------------------------------------------------------------


select niv_libelle, count(zhu_vse_zhu) 
from fma.zhu_vse, fma.niveau 
where  niv_id=zhu_vse_imp and zhu_vse_vse = 3
group by niv_libelle
order by niv_libelle;

"1";3552
"2";430
"3";829

-- Mettre à jour l'indicateur
-- niveau corrigé en 0 (le 28/07/2017)

update note i set i_brut = 0, missing = false 
from 
(select 'B1', zhu_vse_zhu, niv_libelle::int as niveau
from fma.zhu_vse, fma.niveau
where niv_id=zhu_vse_imp and zhu_vse_vse = 3) as k
where code_ind = 'B11' and i.zhu_gid = k.zhu_vse_zhu ;  

------------------------------------------------------------------------------------------------------
-- indicateur 30 - bio_densiterichesse - C6
-- #habitats/Aire de ZHU * 10000 * 100
------------------------------------------------------------------------------------------------------


select gid, count(distinct zhu_cbi_cbi)+1
from  fma.zone_humide zhu, fma.zhu_cbi cbi
where zhu.gid = cbi.zhu_cbi_zhu and zhu_cbi!=zhu_cbi_cbi
group by gid
order by gid;
-- 15095 lignes

select gid, count(distinct zhu_cbi_cbi)
from  fma.zone_humide zhu, fma.zhu_cbi cbi
where zhu.gid = cbi.zhu_cbi_zhu and zhu_cbi=zhu_cbi_cbi
group by gid
order by gid;
-- 258 lignes

-- 577309;1

select gid, zhu_cbi, zhu_cbi_cbi
from  fma.zone_humide zhu, fma.zhu_cbi cbi
where zhu.gid = cbi.zhu_cbi_zhu and gid = 577309;

select gid, zhu_cbi, zhu_cbi_cbi
from  fma.zone_humide zhu, fma.zhu_cbi cbi
where zhu.gid = cbi.zhu_cbi_zhu and gid = 406770;

select gid, count(distinct biotope) 
from (
	select gid, zhu_cbi_cbi  as biotope
	from  fma.zone_humide zhu, fma.zhu_cbi cbi
	where zhu.gid = cbi.zhu_cbi_zhu 
	union
	select gid, zhu_cbi as biotope
	from  fma.zone_humide zhu 
	where zhu_cbi is not null
	-- 464622 lignes
) as k
group by gid
order by gid;
-- 438112

-- 1452277 : 199.379941061855 %
	select gid, count(distinct biotope) as nb_biotopes, avg(aire) as aire
	from (
		select gid, zhu_cbi_cbi  as biotope, st_area(zhu.geom) as aire
		from  fma.zone_humide zhu, fma.zhu_cbi cbi
		where zhu.gid = cbi.zhu_cbi_zhu 
		union
		select gid, zhu_cbi as biotope, st_area(zhu.geom) as aire
		from  fma.zone_humide zhu 
		where zhu_cbi is not null
		-- 464622 lignes
	) as k
	where gid = 1452277
	group by gid;

select 1/50.1554968205032 * 10000 * 100;

-- calcul = #habitats/Aire de ZHU * 10000 * 100
update note i set i_brut = calcul, missing = false 
from (
	select 'C6' as numero_ind, gid, nb_biotopes/aire * 10000*100   as calcul
	from ( 
		select gid, count(distinct biotope) as nb_biotopes, avg(aire) as aire
		from (
			select gid, zhu_cbi_cbi  as biotope, st_area(zhu.geom) as aire
			from  fma.zone_humide zhu, fma.zhu_cbi cbi
			where zhu.gid = cbi.zhu_cbi_zhu 
			union
			select gid, zhu_cbi as biotope, st_area(zhu.geom) as aire
			from  fma.zone_humide zhu 
			where zhu_cbi is not null
			-- 464622 lignes
		) as k
		group by gid
		order by gid
	) as q
) as k
where code_ind = 'C6' and i.zhu_gid = k.gid   ;
-- Query returned successfully: 438112 rows affected, 01:53 minutes execution time.

/* Beaucoup de ZHU ne sont pas en relation avec un biotope */
select * from indicateurs.note where code_ind = 'C6' and  missing is true
-- 137523 ZHU
select 137523 / 600000.0 
-- 22%
-- On les calibre comme faible en biotope. 
update indicateurs.note set i_calibre = 1 where code_ind = 'C6' and  missing is true
-- Query returned successfully: 137523 rows affected, 16.9 secs execution time.

------------------------------------------------------------------------------------------------------
-- Insertion de la France_metropole dans les referentiels
------------------------------------------------------------------------------------------------------

-- import d'une table france_metropole
-- shp2pgsql -c -I /home/forum/donnees/FranceMetro/FRANCE_METROPOLE3 referentiels.france_metropole | psql -d forum -U postgres
alter table referentiels.france_metropole drop column id_geofla;
alter table referentiels.france_metropole drop column nom_chf;
alter table referentiels.france_metropole drop column code_dept;
alter table referentiels.france_metropole drop column nom_dept;
alter table referentiels.france_metropole drop column code_chf;
alter table referentiels.france_metropole drop column x_chf_lieu;
alter table referentiels.france_metropole drop column y_chf_lieu;
alter table referentiels.france_metropole drop column x_centroid;
alter table referentiels.france_metropole drop column y_centroid;
alter table referentiels.france_metropole drop column code_reg;
alter table referentiels.france_metropole drop column nom_reg;

select * from indicateurs.masque_test;
 
insert into indicateurs.masque_test (id, geom, nom) (
	select 4 as id, geom, 'france' as nom from referentiels.france_metropole
);

alter table indicateurs.masque_test alter column  geom type geometry;

select id, nom, st_area(geom), st_srid(geom) from indicateurs.masque_test;
4;"france";540076624255.933;2154
1;"marais79";3095346064.27212;2154
2;"idf";2066343253.68542;2154
3;"garonne";1335410804.83298;2154

update indicateurs.masque_test set geom = st_setsrid(geom, 2154) where id = 4;
update referentiels.france_metropole set geom = st_setsrid(geom, 2154) ;

---------------------------------------------------------------------------------------------------------------------------
--- GRILLE
---------------------------------------------------------------------------------------------------------------------------

create table indicateurs.grille (
	ogc_fid serial,
	geom geometry,
	idzone integer,
	nom_zone varchar(256),
	ligne integer,
	colonne integer
);
-- OK
drop table grille


create or replace function create_grille(pas_x real, pas_y real, p_nom_zone varchar(256), p_idzone integer) returns integer as $BODY$
declare

	ligne integer;
	colonne integer;
	calculs RECORD;
	limites RECORD;
	iterx integer;
	itery integer;
	geom geometry;
	-- calculs.iterx integer; -- nombre de colonnes
	-- calculs.itery integer; -- nombre de lignes

begin
	SELECT into limites st_xmin(ST_Extent(m.geom)) as xmin, ST_XMax(ST_Extent(m.geom)) as xmax, st_ymin(ST_Extent(m.geom)) as ymin, st_ymax(ST_Extent(m.geom)) as ymax
	FROM indicateurs.masque_test m where nom=p_nom_zone;
	--SELECT into calculs st_xmin(ST_Extent(geom)) as xmin, ST_XMax(ST_Extent(geom)) as xmax, st_ymin(ST_Extent(geom)) as ymin, st_ymax(ST_Extent(geom)) as ymax FROM grille_extrait;

	select into iterx floor((limites.xmax-limites.xmin)/pas_x + 2);
	select into itery floor((limites.ymax-limites.ymin)/pas_y + 2);

	RAISE NOTICE 'iter_x (%) - iter_y (%)', iterx, itery;

	ligne := 0;
	WHILE ligne < itery+1 LOOP
		colonne :=0;
		WHILE colonne < iterx+1 LOOP
			insert into indicateurs.grille (geom, ligne, colonne, nom_zone, idzone)
			VALUES (st_setsrid(ST_MakeEnvelope(limites.xmax-pas_x*(colonne+1), limites.ymin+pas_y*ligne, limites.xmax-pas_x*colonne, limites.ymin+pas_y*(ligne+1)), 2154), ligne, colonne, p_nom_zone, p_idzone);
			colonne :=colonne+1;
		END LOOP;
		ligne:=ligne+1;
	END LOOP;

	return itery;
end;
$BODY$ language plpgsql;




select create_grille(500, 500, 'france', 4 );
-- 1948
-- NOTICE:  iter_x (1969) - iter_y (1948)
-- Total query runtime: 01:50 minutes
-- 1 ligne récupérée.

select st_srid(geom) from indicateurs.grille;
-- 3 839 530 lignes

CREATE INDEX grille_geom_idx
  ON indicateurs.grille
  USING gist
  (geom);
-- Query returned successfully with no result in 01:03 minutes.


------------------------------------------------------------------------------------------------------
-- indicateur 32 - bio_densitezhu (C7)
-- 1/n * somme(surface(Ai))/500^2, n : nombre des carreaux que la zhu testée intersecte
------------------------------------------------------------------------------------------------------


-- Requete de test sur la zhu 23
select sum(st_area(st_intersection(q.cgeom, zhu.geom)))/500^2/ count(c)
from fma.zone_humide zhu,
	(select ogc_fid as c, grille.geom as cgeom 
	from indicateurs.grille grille, fma.zone_humide zhu
	where st_intersects(grille.geom, zhu.geom) and zhu.gid = 23) 
	-- 350 lignes
	as q
where st_intersects(q.cgeom, zhu.geom) and 
zhu.gid not in (405007,405235,405812,406312,406589,406641,2286180,2375241,4903324,4906542)


-- mise à jour avec la zhu 23 : prend du temps
update note i set i_brut = calcul, missing = false 
from (
select sum(st_area(st_intersection(q.cgeom, zhu.geom)))/500^2/ count(c) as calcul, q.zhu_testee
from fma.zone_humide zhu,
	(select ogc_fid as c, grille.geom as cgeom , gid as zhu_testee
	from indicateurs.grille grille, fma.zone_humide zhu
	where st_intersects(grille.geom, zhu.geom) ) 
	-- 350 lignes
	as q
where st_intersects(q.cgeom, zhu.geom) and 
zhu.gid not in (405007,405235,405812,406312,406589,406641,2286180,2375241,4903324,4906542)
group by q.zhu_testee
limit 2
) as k
where code_ind = 'C7' and i.zhu_gid = k.zhu_testee   
-- Query returned successfully: 2 rows affected, 47.1 secs execution time.

select * from note where code_ind = 'C7' and missing is false
-- 2 min 29 pour 23 entités (limit 23 à la place de limit 2) : C'EST TROP LONG
0.0705702802987206;1
0.0705702802987206;2
0.497798517894564;3
0.576932584725623;4
0.573078887602321;5
0.457305410532062;6
0.274626403069283;7
0.451292116395361;8
0.161136233319807;9
0.57527182051236;10
0.575576302148537;11
0.637966710371491;12
0.582632374644917;13
0.688710110009909;14
0.429518321340613;15
0.69585795257089;16
0.382781750952068;17
0.633361529100026;18
0.590461367760822;19
0.686231445245052;20
0.612428894778414;21
0.497049866634835;22
0.69103146050539;23

-- Table créée pour précalculer les intersections entre grille et zhu
create table indicateurs.tampon_grille as 
(select ogc_fid as c, grille.geom as cgeom , gid as zhu_testee
	from indicateurs.grille grille, fma.zone_humide zhu
	where st_intersects(grille.geom, zhu.geom) and 
	zhu.gid not in (405007,405235,405812,406312,406589,406641,2286180,2375241,4903324,4906542)
	);
-- Query returned successfully: 974783 rows affected, 01:02 minutes execution time.

CREATE INDEX tampon_grille_geom_idx
  ON indicateurs.tampon_grille
  USING gist
  (cgeom);
-- Query returned successfully with no result in 8.6 secs.  

CREATE INDEX tampon_grille_zhugid_idx
  ON indicateurs.tampon_grille    (zhu_testee);
-- Query returned successfully with no result in 1.4 secs.

vacuum analyze indicateurs.tampon_grille;
-- Query returned successfully with no result in 1.3 secs.

-- Test à petite échelle (2 ZHU)
update note i set i_brut = calcul, missing = false 
from (
	select sum(st_area(st_intersection(q.cgeom, zhu.geom)))/500^2/ count(c) as calcul, q.zhu_testee
	from fma.zone_humide zhu, tampon_grille  q
	where st_intersects(q.cgeom, zhu.geom) and 
	zhu.gid not in (405007,405235,405812,406312,406589,406641,2286180,2375241,4903324,4906542)
	group by q.zhu_testee
	limit 2
) as k
where code_ind = 'C7' and i.zhu_gid = k.zhu_testee  ;   
-- Query returned successfully: 2 rows affected, 10.4 secs execution time.  

-- Requete à grande échelle (2 ZHU)
update note i set i_brut = calcul, missing = false 
from (
	select sum(st_area(st_intersection(q.cgeom, zhu.geom)))/500^2/ count(c) as calcul, q.zhu_testee
	from fma.zone_humide zhu, tampon_grille  q
	where st_intersects(q.cgeom, zhu.geom) and 
	zhu.gid not in (405007,405235,405812,406312,406589,406641,2286180,2375241,4903324,4906542)
	group by q.zhu_testee
) as k
where code_ind = 'C7' and i.zhu_gid = k.zhu_testee   ;
-- SET
-- UPDATE 573298

-- Sur forum, création d'un script
vi /hom/plumegeo/data_forum/scriptsSQL/C7_bio_densitezhu.sql

nohup psql -U postgres -d forum -f C7_bio_densitezhu.sql > C7_bio_densitezhu.txt  &
/*
plumegeo@cchum-kvm-mapuce:~$ ps -ef | grep psql
plumegeo 24995  7103  0 17:54 pts/0    00:00:00 /usr/lib/postgresql/9.6/bin/psq  -U postgres -d forum -f C7_bio_densitezhu.sql
plumegeo 25019 23383  0 17:55 pts/1    00:00:00 grep --color=auto psql
FIN : 18:45
*/

/* Quelques ZHU sont isolée */
select count(*) from indicateurs.note where code_ind = 'C7' and  missing is true
-- 2337 ZHU
select 2337 / 600000.0 
-- 0.03%
-- On les calibre comme faible en densité. 
update indicateurs.note set i_calibre = 1 where code_ind = 'C7' and  missing is true
-- Query returned successfully: 2337 rows affected, 3.7 secs execution time.

------------------------------------------------------------------------------------------------------
-- indicateur 33 - bio_potentielzhu (C8)
-- calculer le potentiel d'une ZHU
------------------------------------------------------------------------------------------------------

TODO

------------------------------------------------------------------------------------------------------
-- Traitement sur les données d'eau dans le référentiel
------------------------------------------------------------------------------------------------------



-- Ok donc les points d'eau sont bien 2154 en fait
alter table referentiels.point_eau alter wkb_geometry TYPE geometry;
update referentiels.point_eau set wkb_geometry = st_setsrid(wkb_geometry, 2154)
-- Query returned successfully: 140223 rows affected, 2.6 secs execution time.

 select st_srid(wkb_geometry) from referentiels.surface_eau limit 10
alter table referentiels.surface_eau alter wkb_geometry TYPE geometry;
update referentiels.surface_eau set wkb_geometry = st_setsrid(wkb_geometry, 2154)
-- Query returned successfully: 899241 rows affected, 01:27 minutes execution time.

select count(*) from referentiels.troncon_cours_eau
-- 2404025
select st_srid(wkb_geometry) from referentiels.troncon_cours_eau limit 10
alter table referentiels.troncon_cours_eau alter wkb_geometry TYPE geometry;
update referentiels.troncon_cours_eau set wkb_geometry = st_setsrid(wkb_geometry, 2154)
-- Query returned successfully: 2404025 rows affected, 03:44 minutes execution time.



CREATE INDEX point_eau_the_geom_gist ON referentiels.point_eau USING GIST (wkb_geometry); --fait
CREATE INDEX surface_eau_the_geom_gist ON referentiels.surface_eau USING GIST (wkb_geometry); -- fait
CREATE INDEX troncon_cours_eau_the_geom_gist ON referentiels.troncon_cours_eau USING GIST (wkb_geometry);

VACUUM ANALYZE referentiels.point_eau;
VACUUM ANALYZE referentiels.surface_eau;
VACUUM ANALYZE referentiels.troncon_cours_eau;

COMMENT ON TABLE  referentiels.point_eau IS 'Source (captée ou non), point de production d''eau (pompage, forage, puits,…) ou point de stockage d’eau de petite dimension (citerne, abreuvoir, lavoir, bassin).';

select distinct nature from  referentiels.point_eau
/*
"Source captée"
"Fontaine"
"Source"
"Citerne"
"Station de pompage"
"Autre point d'eau"
*/

-- D'après les spécifications de l'IGN, il faudrait exclure nature == Citerne dans notre analyse

COMMENT ON TABLE  referentiels.surface_eau IS 'Toutes les surfaces d''eau de plus de 20 m de long sont incluses, ainsi que les cours d''eau de plus de 7,5 m de large. Tous les bassins maçonnés de plus de 10 m sont inclus. Les zones inondables périphériques (zone périphérique d''un lac de barrage, d''un étang à niveau variable) de plus de 20 m de large sont incluses (attribut régime = intermittent).';

select distinct nature from  referentiels.surface_eau
/*
"Bassin"
"Surface d'eau"
*/

COMMENT ON TABLE  referentiels.troncon_cours_eau IS 'Portion de cours d''eau, réel ou fictif, permanent ou temporaire, naturel ou artificiel, homogène pour l''ensemble des attributs qui la concernent, et qui n''inclut pas de confluent.';
-- si FICTIF, exclure du calcul car c'est la distance à la surface d'eau qui compte alors.


------------------------------------------------------------------------------------------------------
-- indicateur 34 - eau_supercie (D1) 
-- agréger les zhu sur un buffer de 50 m, puis calculer l'aire des agrégats. 
-- Si < 3ha : 1; <10ha : 2; > 10ha : 3
------------------------------------------------------------------------------------------------------

select avg(k.aire), min(k.aire), max(k.aire), stddev(k.aire) from 
(SELECT gid as zhu_testee, st_area ( (st_dump(ST_Union(ARRAY( select st_buffer(geom, 50) from fma.zone_humide )))).geom ) / 10000 as aire) as k

-- par défaut
update indicateurs.note i set i_calibre = 3 where code_ind = 'D1';
-- La requête a été exécutée avec succés : 575635 lignes modifiées. La requête a été exécutée en 33261 ms.
select distinct i_calibre from indicateurs.note where code_ind = 'D1';

-- Pour tester la requete
-- Juste celle du masque 1
SELECT st_area ( (st_dump(ST_Union(ARRAY( select st_buffer(geom, 50) from christine.zone_humide_test where masque_id = 1)))).geom ) / 10000
-- 317 geom de typeo POLYGON / 4698 en 7 secondes
select count(*) from fma.zone_humide
-- 573308

--- Créer la table des buffer à 50 autour des ZHU
create table zhu_buffer50 as (
SELECT (
	st_dump(ST_Union(ARRAY( select st_buffer(geom, 50) from fma.zone_humide)))).geom 
) 
--- La requête a été exécutée avec succés : 78611 lignes modifiées. La requête a été exécutée en 9410598 ms.
-- 2h36 min

ALTER TABLE zhu_buffer50 SET SCHEMA indicateurs;
COMMENT ON TABLE zhu_buffer50 IS 'ensemble des géométries créées par un buffer de 50 m autour des zhu, avec union par dissolution de leurs frontières. Méthode directe'

select count(*) from zhu_buffer50
-- 78611


--- drop table zhu_buffer50
-- Créer un index spatial sur la table
CREATE INDEX public_zhu_buffer50_geom_gist ON public.zhu_buffer50 USING GIST (geom); 
VACUUM ANALYZE public.zhu_buffer50

-- Calculer à quelle geom appartient la zhu testée 

-- Etudier l'appartenance des zhu à ce total
select zhu.gid as zhu_testee, st_area(buf.geom)  / 10000 as aire
from fma.zone_humide zhu, public.zhu_buffer50 buf
where  buf.geom && zhu.geom and st_intersects(zhu.geom, buf.geom)

update indicateurs.note i set i_brut = aire, missing = false,  i_calibre = CASE WHEN aire < 3 THEN 1 ELSE (CASE WHEN aire < 10 THEN 2 ELSE 1 END) END
from (
	select zhu.gid as zhu_testee, st_area(buf.geom)  / 10000 as aire
	from fma.zone_humide zhu, public.zhu_buffer50 buf
	where  zhu.gid not in (405007,405235,405812,406312,406589,406641,2286180,2375241,4903324,4906542) and buf.geom && zhu.geom and st_intersects(zhu.geom, buf.geom)
) as k
where code_ind = 'D1' and i.zhu_gid = k.zhu_testee;   
-- La requête a été exécutée avec succés : 573298 lignes modifiées. La requête a été exécutée en 3788927 ms.
 
-------------------------------------------------------------
-- indicateur 35 - distance au réseau hydrographique (D2)
-- 1 : > 100, 2 : 25 à 100, 3 : < 25 m
-------------------------------------------------------------

-- créer un buffer de 100m autour des ZHU pour l'enregistrer et créer un index spatial dessus
alter table fma.zone_humide add column buffergeom_100 geometry;
update fma.zone_humide set buffergeom_100 = st_buffer(geom, 100);
-- Query returned successfully: 573308 rows affected, 06:37 minutes execution time.
CREATE INDEX zhu_buffergeom100_gist ON fma.zone_humide USING GIST (buffergeom_100); 
-- Query returned successfully with no result in 9.1 secs.

vacuum analyze fma.zone_humide;
-- Query returned successfully with no result in 24.4 secs.

-- par défaut
update indicateurs.note i set i_calibre = 1 where code_ind = 'D2';
-- select i_calibre from indicateurs.note where code_ind = 'D2';

-- distance au réseau hydrographique (surface_eau + troncon_cours_eau)
-- On exclut les tronçons fictifs, et les bassins 
	select zhu_testee, min(dmin) from (
		select gid as zhu_testee, st_distance(wkb_geometry, geom) as dmin
		from referentiels.surface_eau, fma.zone_humide
		where  nature not like 'Bassin' and buffergeom_100 && wkb_geometry 
		-- les surfaces en eau
		union
		select gid as zhu_testee, st_distance(wkb_geometry, geom) as dmin
		from referentiels.troncon_cours_eau, fma.zone_humide
		where fictif like 'Non' and buffergeom_100 && wkb_geometry 
		-- les troncons d'eau
	) as k
	group by zhu_testee 

select distinct fictif from referentiels.troncon_cours_eau 
/*
"Non"
"Oui"
*/

update indicateurs.note i set i_brut = dmin, missing = false,  i_calibre = CASE WHEN dmin < 25 THEN 3 ELSE (CASE WHEN dmin < 100 THEN 2 ELSE 1 END) END
from (
	select zhu_testee, min(dmin) as dmin from (
		select gid as zhu_testee, st_distance(wkb_geometry, geom) as dmin
		from referentiels.surface_eau, fma.zone_humide
		where  nature not like 'Bassin' and buffergeom_100 && wkb_geometry 
		-- les surfaces en eau
		union
		select gid as zhu_testee, st_distance(wkb_geometry, geom) as dmin
		from referentiels.troncon_cours_eau, fma.zone_humide
		where fictif like 'Non' and buffergeom_100 && wkb_geometry 
		-- les troncons d'eau
	) as q
	group by zhu_testee 
) as k
where code_ind = 'D2' and i.zhu_gid = k.zhu_testee;   
-- 17min33, 276978 lignes

------------------------------------------------------------------------------------
-- indicateur 41 - eau_captage, distance à l'eau (D8) 
------------------------------------------------------------------------------------

create table referentiels.captages (
"Type d'eau (ESO/ESU)"    text,
"Code Dept ARS_Gestionnaire"    integer,
"Code national installation"    integer,
"Type d'installation"    text,
"Nom installation"    text,
"Date D.U.P."    date,
"Etat D.U.P."    text,
"Débit réglementaire (m3/j)"    integer,
"Code usage principal"    text,
"Libellé usage principal"    text,
"Date de début d'usage"    date,
"Code état"    text,
"Libellé état"    text,
"Date de début d'état"    date,
"Motif d'abandon"    text,
"Date d'abandon"    date,
"X initiale (m) dans SISE Eaux"    integer,
"Y initiale (m) dans SISE Eaux"    integer,
"Projection initiale"    text,
"Positionnement au centroïde de la commune (O/N)"    text,
"X L2E ou local(DOM/COM) (m) dans SISE Eaux"    integer,
"Y L2E ou local(DOM/COM) (m) dans SISE Eaux"    integer,
"X L93 ou WGS84(DOM/COM) dans SISE Eaux"    double precision,
"Y L93 ou WGS84(DOM/COM) dans SISE Eaux"    double precision,
"Longitude WGS84 dans SISE Eaux"    double precision,
"Latitude WGS84 dans SISE Eaux"    double precision,
"Code INSEE commune"    integer,
"Nom commune dans SISE-EAUX"    text,
"Code département"    integer,
"Région"    text,
"Bassin"    text,
"Code district"    text,
"Indice BSS de SISE-EAUX"    text,
"Désignation BSS de SISE-EAUX"    text,
"Code BSS en BSS"    text,
"Type de qualitomètre"    text,
"Validation ARS"    text,
"Commune du dossier BSS"    integer,
"Commune actuelle"    integer,
"Nom commune actuelle"    text,
"X L2E ou local(DOM/COM) (m) en BSS"    integer,
"Y L2E ou local(DOM/COM) (m) en BSS"    integer,
"X L93 ou WGS84(DOM/COM) en BSS"    integer,
"Y L93 ou WGS84(DOM/COM) en BSS"    integer,
"Longitude WGS84 en BSS"    double precision,
"Latitude WGS en BSS"    double precision,
"Altitude (m)"    double precision,
"Précision altitude"    text,
"Profondeur d'investigation (m)"    double precision,
"Nature du point d'eau"    text,
"Origine du champ Nature"    text,
"Mode de gisement"    text,
"Fracturé (O/N) au droit du point d'eau"    text,
"Code entité hydrogéologique BDRHFV1"    text,
"Date d'affectation du point à l'entité BDRHFV1"    date,
"Code Entité hydrogéologique BDLISA"    text,
"Date d'affectation du point à l'entité BDLISA"    date,
"Code Masse d'eau"    text,
"Version du référentiel masse d'eau"    text,
"Date d'affectation du point à la masse d'eau"    text,
"Date de première information sur l'installation"    date,
"Date de dernière mise à jour"    date
)


alter table referentiels.captages alter "X L2E ou local(DOM/COM) (m) dans SISE Eaux"  type double precision;
alter table referentiels.captages alter "Y L2E ou local(DOM/COM) (m) dans SISE Eaux"  type double precision;
alter table referentiels.captages alter "X L2E ou local(DOM/COM) (m) en BSS"  type double precision;
alter table referentiels.captages alter "Y L2E ou local(DOM/COM) (m) en BSS"  type double precision;
alter table referentiels.captages alter "X L93 ou WGS84(DOM/COM) en BSS"  type double precision;
alter table referentiels.captages alter "Y L93 ou WGS84(DOM/COM) en BSS"  type double precision;
-- Attention  !
alter table referentiels.captages alter "Date d'affectation du point à l'entité BDLISA"  type text;
alter table referentiels.captages alter "Date d'affectation du point à l'entité BDRHFV1"  type text;
alter table referentiels.captages alter "Code Dept ARS_Gestionnaire" type text;
alter table referentiels.captages alter "Code national installation" type text;
alter table referentiels.captages alter "Code INSEE commune" type text;
alter table referentiels.captages alter "Code département" type text;
alter table referentiels.captages alter "Commune du dossier BSS" type text;
alter table referentiels.captages alter "Commune actuelle" type text;


\copy referentiels.captages from  '/home/forum/donnees/captage_prioritaire/captages_UTF8_3.csv' WITH CSV HEADER DELIMITER ';' ENCODING 'UTF8'


select count(*) from referentiels.captages 
-- 52420
where "Longitude WGS84 dans SISE Eaux" is not null and
"Latitude WGS84 dans SISE Eaux" is not null 
-- 52383

select count(*) from
 referentiels.captages 
where "Longitude WGS84 en BSS" is not null and
"Latitude WGS en BSS" is not null 
-- 45139

select st_setsrid(st_makepoint("Longitude WGS84 dans SISE Eaux", "Latitude WGS84 dans SISE Eaux"), 2154)
from referentiels.captages

alter table referentiels.captages add column geom geometry;
update referentiels.captages set geom = st_setsrid(st_makepoint("Longitude WGS84 dans SISE Eaux", "Latitude WGS84 dans SISE Eaux"), 2154)
-- La requête a été exécutée avec succés : 52420 lignes modifiées. La requête a été exécutée en 680 ms.

update referentiels.captages set geom = st_setsrid(geom, 4326);
update referentiels.captages set geom = st_setsrid(st_transform(geom, 2154), 2154);

CREATE INDEX captages_geom_gist ON referentiels.captages USING GIST (geom); 
vacuum analyze referentiels.captages;

select count(*) from referentiels.captages
 -- 52420 * 600 000
 
-- On teste l'usage de l'index spatial pour limiter la volume de la requete (wkb_geometry && geom) 
select gid, min(st_distance(eau.geom, zhu.geom))
 from referentiels.captages eau, fma.zone_humide zhu
 where eau.geom && zhu.geom
 group by gid
 -- il pourrait rester des ZHU orphelines de point d'eau (leur étendue ne croiserait pas celle d'un point d'eau). Dans ce cas, relancer la requetes sur celles-ci seulement
-- 1927 lignes seulement...Total query runtime: 60 secs

-- créer un buffer de 500 m autour des zhu pour voir s'il intersecte un point de captage
select gid, min(st_distance(eau.geom, zhu.geom))
 from referentiels.captages eau, fma.zone_humide zhu
where st_buffer(geom, 500) && eau.geom 
 group by gid
-- C'est long....
 
-- créer un buffer de 500m autour des ZHU pour l'enregistrer et créer un index spatial dessus
alter table fma.zone_humide add column buffergeom_500 geometry;
update fma.zone_humide set buffergeom_500 = st_buffer(geom, 500);
-- Query returned successfully: 573308 rows affected, 06:02 minutes execution time.
CREATE INDEX zhu_buffergeom_gist ON fma.zone_humide USING GIST (buffergeom_500); 
-- Query returned successfully with no result in 9.1 secs.

vacuum analyze fma.zone_humide;
-- Query returned successfully with no result in 12.9 secs.

-- créer un buffer de 500 m autour des zhu pour voir s'il intersecte un point de captage
select gid, min(st_distance(eau.geom, zhu.geom)) as dmin
 from referentiels.captages eau, fma.zone_humide zhu
where buffergeom_500 && eau.geom 
 group by gid
 --- 26491 lignes, 30 sec

-- par défaut, tout le monde est à plus de 500m  d'un point de captage
update indicateurs.note i set i_calibre = 1, i_brut = dmin, missing = false where code_ind = 'D8';
-- Query returned successfully: 575635 rows affected, 01:23 minutes execution time.

-- Si on utilise la couche referentiels.point_eau
update indicateurs.note i set i_brut = dmin, missing = false,  i_calibre = CASE WHEN dmin < 150 THEN 3 ELSE (CASE WHEN dmin < 500 THEN 2 ELSE 1 END) END
from (
	select gid as zhu_testee, min(st_distance(eau.wkb_geometry, zhu.geom)) as dmin
	from referentiels.point_eau eau, fma.zone_humide zhu
	where buffergeom_500 && eau.wkb_geometry 
	group by gid 
) as k
where code_ind = 'D8' and i.zhu_gid = k.zhu_testee;   
-- Query returned successfully: 108422 rows affected, 01:13 minutes execution time.

-- En utilisant les captages
update indicateurs.note i set i_calibre = 1 where code_ind = 'D8';
-- Query returned successfully: 575635 rows affected, 01:23 minutes execution time.
update indicateurs.note i set i_brut = dmin, missing = false,  i_calibre = CASE WHEN dmin < 150 THEN 3 ELSE (CASE WHEN dmin < 500 THEN 2 ELSE 1 END) END
from (
	select gid as zhu_testee, min(st_distance(pt.geom, zhu.geom)) as dmin
	from referentiels.captages pt, fma.zone_humide zhu
	where buffergeom_500 && pt.geom 
	group by gid 
) as k
where code_ind = 'D8' and i.zhu_gid = k.zhu_testee;   
-- Query returned successfully: 26491 rows affected, 01:40 minutes execution time.

------------------------------------------------------------------------------------
-- indicateur 44 - eau_masse, contribution des aires des ZHU à un tronceau de masse d'eau(D9) 
------------------------------------------------------------------------------------


ogr2ogr -f "PostgreSQL" PG:"host=localhost port=5432 user=forum dbname=forum password=******** schemas=referentiels"  /home/forum/donnees/MASSE_D_EAU_COURS_D_EAU/MasseDEauRiviere_FXX.shp -nlt PROMOTE_TO_MULTI -a_srs "EPSG:2154" -nln masse_eau

-- verser le linéaire dans un graphe avec pg_routing. 
-- cela permettra de récupérer les différents arc et noeuds du réseau

psql -U postgres -d forum -c "create extension pgrouting"

drop schema hydro cascade
/*
NOTICE:  DROP cascade sur 9 autres objets
DETAIL:  DROP cascade sur table hydro.face
DROP cascade sur table hydro.node
DROP cascade sur table hydro.edge_data
DROP cascade sur vue hydro.edge
DROP cascade sur séquence hydro.layer_id_seq
DROP cascade sur table hydro.relation
DROP cascade sur table hydro.reseau
DROP cascade sur table hydro.masse_eau_line
DROP cascade sur séquence hydro.topogeo_s_1
*/
delete from topology.layer where schema_name = 'hydro';
delete from topology.topology where name='hydro' ;

SELECT topology.CreateTopology('hydro', 2154);
-- 3

ALTER TABLE  referentiels.masse_eau ADD COLUMN geom geometry (LINESTRING,2154);
ALTER TABLE  referentiels.masse_eau DROP COLUMN geom
ALTER TABLE  referentiels.masse_eau ADD COLUMN geom geometry (MultiLineString,2154);

UPDATE  referentiels.masse_eau SET geom=st_transform(wkb_geometry,2154);

/*
-- Table temporaire, qui est un extrait de referentiels.masse_eau correspondant au marais poitevin
CREATE TABLE hydro.reseau as 
SELECT a.ogc_fid, a.cdeumassed, a.datecreati, a.typegeneal, a.nommassede, a.datemajmas, a.surfacetot, a.cdmassedea, a.cdeubassin, a.stmassedea, a.cdcategori, a.systemeref, st_intersection( a.geom,b.geom) as geom  
FROM referentiels.masse_eau a, christine.masque_test b 
WHERE b.nom = 'marais79' and a.geom && b.geom and ST_intersects(a.geom,b.geom) ; 
-- Query returned successfully: 33 rows affected, 4.6 secs execution time.

CREATE INDEX idx_hydro_reseau_geom  ON hydro.reseau  USING gist  (geom);
*/

create table hydro.masse_eau_line (id integer);
select topology.addTopoGeometryColumn('hydro', 'hydro', 'masse_eau_line', 'topogeom', 'MULTILINESTRING')
-- 1


insert into hydro.masse_eau_line (id, topogeom) 
select a.ogc_fid, topology.toTopoGeom(geom, 'hydro', 1)
from referentiels.masse_eau a;
-- La requête a été exécutée avec succés : 9878 lignes modifiées. La requête a été exécutée en 1266372 ms.

/* Description du schema hydro et des objets topologiques en particulier */

-- Voies.edge est une vue qui présente les arcs du graphes avec les nœuds entrants et sortants (des Segments)
select * from hydro.edge_data limit 10
-- edge_id, start_node, end_node, geom (linestring, 2154)

-- hydro.node montre les nœuds (des Points)
select * from hydro.node limit 10
-- node_id, geom (point, 2154)


-- Maintenant, on veut travailler uniquement sur les edges, sur lesquels on souhaite créer un buffer de 100 m, pour trouver ensuite les ZHU dans la buffer

alter table hydro.edge_data add column geom_buffer100 geometry;
-- Query returned successfully with no result in 63 msec.

update hydro.edge_data set geom_buffer100 = st_buffer(geom, 100)
-- La requête a été exécutée avec succés : 118277 lignes modifiées. La requête a été exécutée en 54938 ms.

CREATE INDEX hydro_edge_data_geom_buffer100_gist ON hydro.edge_data USING GIST (geom_buffer100); 
vacuum analyze hydro.edge_data ;

-- A METTRE A JOUR
-- La table indicateurs.hydro_zhu sera à refraîchir à chaque nouvelle entrée de ZHU
GRANT ALL on ALL TABLES in SCHEMA indicateurs to forum
drop table indicateurs.hydro_zhu
-- ICI
select count(*) from hydro.edge_data
-- 118277

create table indicateurs.hydro_zhu as
(select edge_id, zhu.gid as zhu_id, st_area(zhu.geom) as zhu_aire
	from hydro.edge_data eau, fma.zone_humide zhu
	where zhu.gid not in (405007,405235,405812,406312,406589,406641,2286180,2375241,4903324,4906542) and eau.geom_buffer100 && zhu.geom and st_intersects(eau.geom_buffer100, zhu.geom))
-- Query returned successfully: 2891 rows affected, 1.7 secs execution time.
-- SELECT 311484


CREATE INDEX indicateurs_hydro_zhu_idx ON indicateurs.hydro_zhu (edge_id, zhu_id);
VACUUM ANALYZE indicateurs.hydro_zhu;

-- précalcul 1 : la surface totale des zhu qui contribuent sur le même réseau que la zhu étudiée
update indicateurs.note i set i_brut = contrib, missing = false
from (
	select h.zhu_id, sum(tot) as contrib
	from 
		(select edge_id, sum(zhu_aire) as tot
			from indicateurs.hydro_zhu
			group by edge_id
		) as k, 
	      indicateurs.hydro_zhu h	
	where 
		k.edge_id = h.edge_id
	group by h.zhu_id
	
) as q
where code_ind = 'D9' and i.zhu_gid = q.zhu_id; 
-- Query returned successfully: 1512 rows affected, 9.1 secs execution time.
-- UPDATE 235584

-- Finaliser avec la contribution réelle
update indicateurs.note i set i_brut = st_area(geom)/i_brut * 100, missing = false 
from fma.zone_humide zhu 
where code_ind = 'D9' and missing is false and i.zhu_gid = zhu.gid and i_brut> 0; 
-- Query returned successfully: 120333 rows affected, 02:18 minutes execution time.
-- UPDATE 235584

-- Vérification
select * from indicateurs.note where code_ind = 'D9' and  zhu_gid in (417334, 36)
/*
36;"D9";0.35574212231924;f;2
417334;"D9";0.000260912377663283;f;3
*/




