
select tsal.ccuenta,codigocontable, tsal.SUBCUENTA, tsal.CATEGORIA,TSAL.CESTATUSCUENTA, tsal.csucursal, tsal.coficina,
nvl((select sum (DECODE(ts.ctiposaldocategoria,'SAL',ts.saldomonedaoficial+
                            COALESCE( ts.ajusteinteresoficial,0)-COALESCE(
                            ts.montodescargaprovisionoficial,0),'ACC', ROUND(
                            ts.saldomonedaoficial+(NVL(ts.provisiondia,0) *(
                                CASE
                                    WHEN tg.PROVISIONAHASTA = 'FPA'
                                    THEN to_date(:fecha,'yyyy-mm-dd')+1
                                    ELSE (
                                            CASE
                                                WHEN to_date(:fecha,'yyyy-mm-dd')+1 > COALESCE(
                                                    ts.fvencimiento, to_date(:fecha,'yyyy-mm-dd') +1)
                                                THEN ts.fvencimiento
                                                ELSE to_date(:fecha,'yyyy-mm-dd')+1
                                            END)
                                END-ts.fdesde))+COALESCE(
                            ts.ajusteinteres,0), 2) - coalesce(ts.montodescargaprovision, 0))) saldo_ant
        		FROM
                            tsaldos ts
                        LEFT OUTER JOIN TGRUPOCATEGORIASUBSISTEMA tg
                        ON
                            ts.CATEGORIA = tg.categoria
                        AND ts.cgrupobalance = tg.cgrupobalance
                        AND tg.cpersona_compania = 2
                        AND tg.fhasta = fncfhasta
                        WHERE
                            to_date(:fecha,'yyyy-mm-dd') BETWEEN ts.fdesde AND ts.fhasta
                        AND ts.codigocontable = tsal.codigocontable
                        AND ts.cpersona_compania=2
                        AND ts.csucursal = tsal.csucursal
                        AND ts.coficina = tsal.coficina
                        and ts.ccuenta = tsal.ccuenta
                        and ts.subcuenta = tsal.subcuenta
                        and ts.categoria = tsal.categoria
                        group by ts.ccuenta), 0) saldo_ant, 
                        nvl ((select sum (valormonedacuenta) 
                        from tmovimientos tmov
                        where tmov.ccuenta = tsal.ccuenta
                        and tmov.codigocontable = tsal.codigocontable
                        and numeromensaje_reverso IS NULL
                        AND reverso = '0'
                        and fcontable BETWEEN to_date(:fecha,'yyyy-mm-dd')+1 AND to_date(:fechaUPDATE,'yyyy-mm-dd')
                        and debitocredito = 'D'
                        and tmov.subcuenta = tsal.subcuenta
                        and tmov.categoria = tsal.categoria
                        and tmov.csucursal_cuenta = tsal.csucursal
                        and tmov.coficina_cuenta = tsal.coficina
                       ), 0) debitos ,
                        nvl ((select sum (valormonedacuenta) 
                        from tmovimientos tmov
                        where tmov.ccuenta = tsal.ccuenta
                        and tmov.codigocontable = tsal.codigocontable
                        and numeromensaje_reverso IS NULL
                        AND reverso = '0'
                        and fcontable BETWEEN to_date(:fecha,'yyyy-mm-dd')+1 AND to_date(:fechaUPDATE,'yyyy-mm-dd')
                        and debitocredito = 'C'
                        and tmov.subcuenta = tsal.subcuenta
                        and tmov.categoria = tsal.categoria
                        and tmov.csucursal_cuenta = tsal.csucursal
                        and tmov.coficina_cuenta = tsal.coficina
                       ), 0) creditos, 
nvl((select sum (DECODE(ts.ctiposaldocategoria,'SAL',ts.saldomonedaoficial+
                            COALESCE( ts.ajusteinteresoficial,0)-COALESCE(
                            ts.montodescargaprovisionoficial,0),'ACC', ROUND(
                            ts.saldomonedaoficial+(NVL(ts.provisiondia,0) *(
                                CASE
                                    WHEN tg.PROVISIONAHASTA = 'FPA'
                                    THEN to_date(:fechaUPDATE,'yyyy-mm-dd')+1
                                    ELSE (
                                            CASE
                                                WHEN to_date(:fechaUPDATE,'yyyy-mm-dd')+1 > COALESCE(
                                                    ts.fvencimiento, to_date(:fechaUPDATE,'yyyy-mm-dd') +1)
                                                THEN ts.fvencimiento
                                                ELSE to_date(:fechaUPDATE,'yyyy-mm-dd')+1
                                            END)
                                END-ts.fdesde))+COALESCE(
                            ts.ajusteinteres,0),2) - coalesce(ts.montodescargaprovision, 0))) saldo_ant
        		FROM
                            tsaldos ts
                        LEFT OUTER JOIN TGRUPOCATEGORIASUBSISTEMA tg
                        ON
                            ts.CATEGORIA = tg.categoria
                        AND ts.cgrupobalance = tg.cgrupobalance
                        AND tg.cpersona_compania = 2
                        AND tg.fhasta = fncfhasta
                        WHERE
                            to_date(:fechaUPDATE,'yyyy-mm-dd') BETWEEN ts.fdesde AND ts.fhasta
                        AND ts.codigocontable = tsal.codigocontable
                        AND ts.cpersona_compania=2
                        AND ts.csucursal = tsal.csucursal
                        AND ts.coficina = tsal.coficina
                        and ts.ccuenta = tsal.ccuenta
                        and ts.subcuenta = tsal.subcuenta
                        and ts.categoria = tsal.categoria
                        group by ts.ccuenta), 0) saldo_act                       
from 
((select tsal.ccuenta, tsal.codigocontable, tsal.SUBCUENTA, tsal.CATEGORIA,TSAL.CESTATUSCUENTA, tsal.csucursal, tsal.coficina from tsaldos tsal
LEFT OUTER JOIN TGRUPOCATEGORIASUBSISTEMA tg
on tsal.CATEGORIA = tg.categoria
   AND tsal.cgrupobalance = tg.cgrupobalance
                        AND tg.cpersona_compania = 2
                        AND tg.fhasta = fncfhasta
where 
tsal.ccuenta IN ('60000534864')
--tsal.ccuenta IN ('44650950')
--tsal.codigocontable  = '510435'
--AND tsal.CGRUPOBALANCE  in ('5')
--tsal.ccuenta IN ('60000545231')
--TSAL.CATEGORIA LIKE 'CXC%'
--AND TSAL.CESTATUSCUENTA = '005'
--AND TSAL.CATEGORIA != 'CXCNOR'
and tsal.principal = 1
--AND tsal.CGRUPOBALANCE = '71'
and to_date(:fechaUPDATE,'yyyy-mm-dd') between tsal.fdesde and tsal.fhasta
group by tsal.ccuenta, tsal.codigocontable, tsal.categoria, tsal.subcuenta, TSAL.CESTATUSCUENTA, tsal.csucursal, tsal.coficina)
union(
select tsal.ccuenta, tsal.codigocontable, tsal.SUBCUENTA, tsal.CATEGORIA, TSAL.CESTATUSCUENTA, tsal.csucursal, tsal.coficina from tsaldos tsal
LEFT OUTER JOIN TGRUPOCATEGORIASUBSISTEMA tg
on tsal.CATEGORIA = tg.categoria
   AND tsal.cgrupobalance = tg.cgrupobalance
                        AND tg.cpersona_compania = 2
                        AND tg.fhasta = fncfhasta
where 
tsal.ccuenta IN ('60000534864')
--TSAL.CATEGORIA like 'CXC%'
--tsal.codigocontable = '510435'
--tsal.CGRUPOBALANCE  in ('5')
/*AND TSAL.CESTATUSCUENTA = '005'
AND TSAL.CATEGORIA != 'CXCNOR'*/
and tsal.principal = 1
and to_date(:fecha,'yyyy-mm-dd') between tsal.fdesde and tsal.fhasta
group by tsal.ccuenta, tsal.codigocontable, tsal.categoria, tsal.SUBCUENTA, TSAL.CESTATUSCUENTA, tsal.csucursal, tsal.coficina)) tsal;

select SUM(VALORMONEDACUENTA) from tmovimientos
where ccuenta = '60000857533' and subcuenta in (11, 12, 13) and ctransaccion = '6014' and categoria = 'INTPRO' AND DEBITOCREDITO ='C' AND CGRUPOBALANCE IN (1,5)
AND FCONTABLE <= '01/07/2020'
and ctransaccion_origen = '6064';

select ctransaccion, debitocredito, categoria, cgrupobalance, valormonedacuenta from tmovimientos
where ccuenta = '60000857533'
and subcuenta =12
and fcontable ='30/06/2020';

select * from tcuentacuotas tc where tc.ccuenta = '60000857533' and subcuenta = 13 order by subcuenta, fdesde

select * from  tsaldos ts
where ccuenta = '60000857533' and ts.subcuenta in (13, 14) and categoria = 'INTPRO' ORDER BY SUBCUENTA, FDESDE;
and FDESDE >= '31/12/2019' and CODIGOCONTABLE = '11010530';

select * from tcuentacolocaciones
where ccuenta = '60000857533'
and fhasta = fncfhasta;

select * from tmovimientos t where t.ccuenta = '278020' and FCONTABLE = '31/05/2020' and subcuenta = 5; 
SELECT * FROM tsaldos ts where 
ts.ccuenta = '50001935979' and ts.fhasta = fncfhasta and  SUBCUENTA = 1 AND PRINCIPAL = 1;

UPDATE "TSALDOS" SET "FHASTA" = TIMESTAMP '2020-06-18 00:00:00', "PARTICION" = '202006', "FCONTABLEHASTA" = TIMESTAMP '2020-06-18 00:00:00' WHERE "CCUENTA" = '50001935979' and "SUBCUENTA" = 1 and "SSUBCUENTA" = 0 and "CPERSONA_COMPANIA" = 2 and "FHASTA" = TIMESTAMP '2999-12-31 00:00:00' and "PARTICION" = '299912' and "CATEGORIA" = 'PLAEFE' and "CGRUPOBALANCE" = '2' and "CSUCURSAL" = 1700 and "COFICINA" = 1721 and "CMONEDA_CUENTA" = 'USD';
UPDATE TSALDOS TS SET PROVISIONDIA = 17.50, PROVISIONDIAOFICIAL = 17.50
WHERE ts.ccuenta = '50001935979' and ts.fhasta = fncfhasta and ts.categoria = 'IDEPP' AND SUBCUENTA = 2 AND PRINCIPAL = 1;


select * from  tsaldos ts
where ccuenta = '60000041452' and subcuenta = 37 
and '31/12/2019' between fdesde and fhasta and CODIGOCONTABLE = '11010530';

select * from tcuentacuotas where ccuenta = '50001935979';

update tmovimientos t set t.VALORMONEDACUENTA = t.VALORMONEDACUENTA - 17.5, t.VALORMONEDAMOVIMIENTO = t.VALORMONEDAMOVIMIENTO - 17.5, t.VALORMONEDAOFICIAL = t.VALORMONEDAOFICIAL - 17.5
where numeromensaje in (
select distinct numeromensaje from tmovimientos t 
where t.codigocontable = '2501150101' and t.ccuenta like 'PR%' and coficina_cuenta = '1721' and fcontable = '18/06/2020' and cestatuscuenta = '002' and cproducto = '101');