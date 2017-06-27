set search_path = indicateurs, fma, referentiels, public;


update note i set i_brut = calcul, missing = false 
from (
	select sum(st_area(st_intersection(q.cgeom, zhu.geom)))/500^2/ count(c) as calcul, q.zhu_testee
	from fma.zone_humide zhu, tampon_grille  q
	where st_intersects(q.cgeom, zhu.geom) and 
	zhu.gid not in (405007,405235,405812,406312,406589,406641,2286180,2375241,4903324,4906542)
	group by q.zhu_testee
) as k
where code_ind = 'C7' and i.zhu_gid = k.zhu_testee   ;


