---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Auteur : Christine Plumejeaud-Perreau
-- 			UMR LIENSs 7266, CNRS et Université de la Rochelle, 
-- 			christine.plumejeaud-perreau@univ-lr.fr
-- Objet : Calcul d'indicateurs (descripteurs) sur les zones humides, pour le Forum des Marais, 
-- Mise à jour : 10, 11, 12 mai 2017 - 23 puis 26 Juin 2017
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
-- indicateur 30 - bio_densiterichesse
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



