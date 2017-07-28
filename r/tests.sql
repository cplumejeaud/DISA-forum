GRANT ALL ON SCHEMA public to forum;
GRANT ALL ON SCHEMA fma to forum;
GRANT ALL ON SCHEMA indicateurs to forum;
GRANT ALL ON SCHEMA referentiels to forum;
GRANT ALL ON SCHEMA topology to forum;


GRANT ALL ON TABLE indicateurs.indicateur to forum;

select count(*) from indicateurs.indicateur;

GRANT ALL ON ALL TABLES IN SCHEMA fma TO forum;
grant all on all sequences in schema fma to forum;

GRANT ALL ON ALL TABLES IN SCHEMA public TO forum;
grant all on all sequences in schema public to forum;

GRANT ALL ON ALL TABLES IN SCHEMA indicateurs TO forum;
grant all on all sequences in schema indicateurs to forum;

GRANT ALL ON ALL TABLES IN SCHEMA referentiels TO forum;
grant all on all sequences in schema referentiels to forum;

GRANT ALL ON ALL TABLES IN SCHEMA topology TO forum;
grant all on all sequences in schema topology to forum;

select count(*) from indicateurs.note where missing is true and code_ind = 'C6'
-- 137524
select * from indicateurs.note where missing is false and code_ind = 'C6'

--- Correction du schéma note
COMMENT ON COLUMN  indicateurs.note.code_ind IS 'référence vers l''indicateur, FK';
COMMENT ON COLUMN  indicateurs.note.missing IS 'Vrai si l''indicateur ne peut être calculé sur cette zone humide';

ALTER TABLE indicateurs.note ADD CONSTRAINT fk_note_indicateur FOREIGN KEY (code_ind)
REFERENCES indicateurs.indicateur (code_ind)
MATCH SIMPLE ON UPDATE CASCADE ON DELETE CASCADE;
-- Si l'indicateur disparait, les notes associées aussi.

ALTER TABLE indicateurs.note ADD CONSTRAINT fk_note_zone_humide FOREIGN KEY (zhu_gid)
REFERENCES fma.zone_humide (gid)
MATCH SIMPLE ON UPDATE CASCADE ON DELETE CASCADE;

/*
ERREUR:  une instruction insert ou update sur la table « note » viole la contrainte de clé
étrangère « fk_note_zone_humide »
DETAIL:  La clé (zhu_gid)=(4910669) n'est pas présente dans la table « zone_humide ».
********** Erreur **********
*/

delete from indicateurs.note where zhu_gid = 4910669
-- Query returned successfully: 46 rows affected, 2.5 secs execution time.

delete from indicateurs.note where zhu_gid not in (select gid from fma.zone_humide)
-- annulée au bout de 30 min

select distinct zhu_gid from indicateurs.note where zhu_gid not in (select gid from fma.zone_humide)
-- rame

create index on  indicateurs.note (zhu_gid)
-- Query returned successfully with no result in 29:55 minutes.

select count(*) from indicateurs.note
-- 26 479 210 lignes

vacuum analyze indicateurs.note
-- Query returned successfully with no result in 34.6 secs.

/*
438107  401476       C6 398.25022   FALSE        -1         2
438108   82444       C6  65.73507   FALSE        -1         1
438109  404193       C6 497.43180   FALSE        -1         2
438110  401497       C6 302.79765   FALSE        -1         2
438111  401499       C6 600.74092   FALSE        -1         2
438112    4969       C6 296.75545   FALSE        -1         2

*/

explain analyze
update indicateurs.note set i_calibre = 2 where code_ind = 'C6' and zhu_gid=4969
-- Query returned successfully: one row affected, 33 msec execution time.
/*
"Update on note  (cost=5.94..787.14 rows=4 width=26) (actual time=0.107..0.107 rows=0 loops=1)"
"  ->  Bitmap Heap Scan on note  (cost=5.94..787.14 rows=4 width=26) (actual time=0.076..0.079 rows=1 loops=1)"
"        Recheck Cond: (zhu_gid = 4969)"
"        Filter: (code_ind = 'C6'::text)"
"        Rows Removed by Filter: 45"
"        Heap Blocks: exact=2"
"        ->  Bitmap Index Scan on note_zhu_gid_idx  (cost=0.00..5.94 rows=200 width=0) (actual time=0.026..0.026 rows=46 loops=1)"
"              Index Cond: (zhu_gid = 4969)"
"Planning time: 0.130 ms"
"Execution time: 0.150 ms"
*/

select count(*) from indicateurs.note where code_ind = 'C6' and missing is false and i_calibre >0
-- 979

select count(*) from indicateurs.note where missing is true and code_ind = 'C7'