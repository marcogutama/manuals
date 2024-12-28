select D.*
from ( select ccuenta, subcuenta, sum(dias) total_dias, sum(valor_calculado) valor_calculado, nvl((select sum(valormonedacuenta)
                                     from tmovimientos where ccuenta = C.ccuenta and subcuenta = C.subcuenta and categoria = 'INTMOR'
                                     and cgrupobalance = '5' and ctransaccion = '6014' and debitocredito = 'C'), 0) valor_cobrado
       from ( select * from ( select B.*, round(saldo * tasa_mora * dias / 36000, 2) valor_calculado
                              from ( select A.*, tcct.tasa, round((tasa * (case when A.fpago - A.fvencimiento between 1 and 15 then 1.05
                                            when A.fpago - A.fvencimiento between 16 and 30 then 1.07 when A.fpago - A.fvencimiento
                                            between 11 and 60 then 1.09 when A.fpago - A.fvencimiento >= 61 then 1.10 end) ), 2) as tasa_mora
                                     from ( select ts.ccuenta, ts.subcuenta, ts.fhasta, ts.fdesde, ts.fhasta + 1 -
                                                   case when ts.fdesde < tcc.fvencimiento then tcc.fvencimiento else ts.fdesde end as dias,
                                                   saldomonedacuenta as saldo, tcc.fvencimiento, tcc.fpago
                                            from tsaldos ts, tcuentacuotas tcc
                                            where ts.ccuenta = tcc.ccuenta and ts.subcuenta = tcc.subcuenta and categoria in ('CAPPRO', 'CAPCAS')
                                                  and principal = '1' and saldomonedacuenta != 0 and ts.fdesde >= (select distinct fdesde from tsaldos
                                                  where ccuenta = ts.ccuenta and subcuenta = ts.subcuenta and categoria in ('CAPPRO', 'CAPCAS')
                                                  and principal = '1' and tcc.fvencimiento between fdesde and fhasta) and tcc.ccuenta in (select ccuenta
                                                  from tcuenta where csubsistema = '06' and fhasta = to_date('31-12-2999', 'dd-mm-yyyy'))
                                                  and tcc.fhasta = to_date('31-12-2999', 'dd-mm-yyyy') and tcc.fvencimiento < tcc.fpago
                                                  and fpago between to_date('01-01-2022', 'dd-mm-yyyy') and to_date('13-11-2022', 'dd-mm-yyyy')
                                          ) A, tcuentacategoriastasas tcct
                            where A.ccuenta = tcct.ccuenta and A.fpago between tcct.fdesde and tcct.fhasta
                        ) B
                )
        ) C
        group by ccuenta, subcuenta
) D
where valor_calculado != valor_cobrado;