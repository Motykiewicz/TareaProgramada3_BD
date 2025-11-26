USE TP3_Municipalidad;
GO
INSERT INTO dbo.PropiedadConceptoCobro(PropiedadID,ConceptoID,Activo)
SELECT p.PropiedadID, cc.ConceptoID, 1
FROM st_CCPropiedad s
JOIN dbo.Propiedad p ON p.Finca=s.Finca
JOIN dbo.ConceptoCobro cc ON cc.Codigo=s.CodigoCC
WHERE cc.Codigo='IMPUESTO' AND NOT EXISTS (SELECT 1 FROM dbo.PropiedadConceptoCobro pc WHERE pc.PropiedadID=p.PropiedadID AND pc.ConceptoID=cc.ConceptoID);
