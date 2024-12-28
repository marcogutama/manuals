Helper.flushTransaction();
SQLQuery query = Helper.getSession().createSQLQuery("select ccuenta, subcuenta, categoria, valorcategoria, valordeudorcategoria, fhasta, fdesde from tcuentacuotascategorias where categoria = :categoria and ccuenta = :ccuenta and subcuenta=5");
        query.setString("categoria", "SEGDES");
        query.setString("ccuenta", "60001858811");
        return query.list(
)

Helper.flushTransaction();
SQLQuery query = Helper.getSession().createSQLQuery("select ccuena, subcuenta, NUMERODIASPROVISION, FVENCIMIENTO, FPAGO, CAPITALREDUCIDO, CAPITAL, INTERES, SEGURO, fhasta, fdesde from tcuentacuotas where ccuenta = '60001858811' and subcuenta=5  order by subcuenta, fdesde");
return query.list();