CREATE DATABASE IF NOT EXISTS bancoPegni;
USE bancoPegni;
SET FOREIGN_KEY_CHECKS=0;

DROP TABLE IF EXISTS dipendenti;
CREATE TABLE dipendenti (
idAziendale INTEGER AUTO_INCREMENT,
nome VARCHAR(40) NOT NULL,
cognome VARCHAR(40) NOT NULL,
reparto VARCHAR(40) NOT NULL,
PRIMARY KEY(idAziendale)
);

DROP TABLE IF EXISTS debitori;
CREATE TABLE debitori (
codiceCliente INTEGER AUTO_INCREMENT,
nome VARCHAR(40) NOT NULL,
cognome VARCHAR(40) NOT NULL,
telefono VARCHAR(40) NOT NULL,
email VARCHAR(40) NOT NULL,
PRIMARY KEY(codiceCliente)
);

DROP TABLE IF EXISTS esperti;
CREATE TABLE esperti (
telefono VARCHAR(40),
email VARCHAR(40) NOT NULL,
nome VARCHAR(40) NOT NULL,
cognome VARCHAR(40) NOT NULL,
campo VARCHAR(40) NOT NULL,
costo FLOAT NOT NULL,
PRIMARY KEY(telefono)
);

DROP TABLE IF EXISTS scontrini;
CREATE TABLE scontrini (
numeroScontrino INTEGER AUTO_INCREMENT,
dataOra DATETIME NOT NULL,
tipo CHAR(1) NOT NULL,
esecutore INTEGER NOT NULL,
PRIMARY KEY(numeroScontrino),
FOREIGN KEY(esecutore) REFERENCES dipendenti(idAziendale),
CHECK(tipo LIKE 'A' OR tipo LIKE 'V')
);

DROP TABLE IF EXISTS prestiti;
CREATE TABLE prestiti (
numeroPrestito INTEGER AUTO_INCREMENT,
dataInizio DATE NOT NULL,
durata INTEGER NOT NULL,
somma FLOAT NOT NULL,
interesse FLOAT NOT NULL,
rinnovo INTEGER,
debitore INTEGER NOT NULL,
responsabile INTEGER NOT NULL,
PRIMARY KEY(numeroPrestito),
FOREIGN KEY(debitore) REFERENCES debitori(codiceCliente),
FOREIGN KEY(responsabile) REFERENCES dipendenti(idAziendale),
CHECK(somma >= 50 AND somma <= 50000),
CHECK(durata <= (31 * 6))
);

DROP TABLE IF EXISTS beni;
CREATE TABLE beni (
idDeposito INTEGER AUTO_INCREMENT,
descrizione TEXT NOT NULL,
tipo VARCHAR(40) NOT NULL,
prezzo FLOAT,
peso FLOAT,
lotto INTEGER,
prestito INTEGER,
acquisito BOOL NOT NULL,
PRIMARY KEY(idDeposito),
FOREIGN KEY(prestito) REFERENCES prestiti(numeroPrestito),
CHECK( (lotto IS NOT NULL AND acquisito IS FALSE) OR (prezzo IS NOT NULL AND acquisito IS TRUE) ) 
);

DROP TABLE IF EXISTS transazioni;
CREATE TABLE transazioni (
prodotto INTEGER,
scontrino INTEGER,
importo FLOAT,
PRIMARY KEY(prodotto, scontrino),
FOREIGN KEY(prodotto) REFERENCES beni(idDeposito),
FOREIGN KEY(scontrino) REFERENCES scontrini(numeroScontrino)
);

DROP TABLE IF EXISTS valutazioni;
CREATE TABLE valutazioni (
esperto VARCHAR(40),
bene INTEGER,
dataValutazione DATE,
valoreStimato FLOAT NOT NULL,
PRIMARY KEY(esperto, bene, dataValutazione),
FOREIGN KEY(esperto) REFERENCES esperti(telefono),
FOREIGN KEY(bene) REFERENCES beni(idDeposito)
);

SET FOREIGN_KEY_CHECKS=1;

DELIMITER $$
CREATE TRIGGER tr_vendita
BEFORE INSERT ON scontrini
FOR EACH ROW BEGIN
IF ( SELECT count(*) FROM beni b
      INNER JOIN transazioni t 
		ON t.prodotto = b.idDeposito  
      INNER JOIN scontrini s
		ON t.scontrino = s.numeroScontrino
      WHERE s.numeroScontrino = NEW.numeroScontrino AND b.acquisito IS FALSE
	) != 0
THEN SIGNAL SQLSTATE '45001' SET MESSAGE_TEXT = 'Si possono vendere o acquistare solo i beni di proprietà del banco';
END IF;
END $$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER tr_numeroImpegnati
BEFORE INSERT ON beni
FOR EACH ROW BEGIN
IF ( SELECT count(*) FROM beni
	WHERE prestito = NEW.prestito) >= 5
THEN SIGNAL SQLSTATE '45002' SET MESSAGE_TEXT = 'Troppi beni associati ad un solo prestito';
END IF;
END $$
DELIMITER ;

DELIMITER $$
CREATE TRIGGER tr_capienza
BEFORE INSERT ON beni
FOR EACH ROW BEGIN
IF (SELECT count(*) FROM beni b
	WHERE b.acquisito IS TRUE) -
   (SELECT count(*) FROM beni b
	INNER JOIN transazioni t 
		ON b.idDeposito = t.prodotto
	INNER JOIN scontrini s 
		ON s.numeroScontrino = t.scontrino
	WHERE s.tipo LIKE 'V')>= 500
THEN SIGNAL SQLSTATE '45003' SET MESSAGE_TEXT = 'Capienza massima raggiunta';
END IF;
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_prestitiScaduti()
BEGIN
	SELECT d.codiceCliente, d.nome, d.cognome, p.numeroPrestito AS prestito, 
		DATE_ADD(p.dataInizio, INTERVAL (p.durata+p.rinnovo) DAY) AS scaduto
    FROM debitori d
	INNER JOIN prestiti p
		ON p.debitore = d.codiceCliente
	WHERE DATE_ADD(p.dataInizio, INTERVAL (p.durata+p.rinnovo) DAY) < CURRENT_DATE();
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_interesseBene(IN in_bene INT)
BEGIN
	SELECT p.interesse FROM prestiti p
	INNER JOIN beni b
		ON b.prestito = p.numeroPrestito
	WHERE b.idDeposito = in_bene;
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_dipMaxPrestiti()
BEGIN
SELECT idAziendale, nome, cognome , ( 
	SELECT count(*) as n 
	FROM prestiti
	WHERE idAziendale = responsabile) as num_prestiti
FROM dipendenti 
ORDER BY num_prestiti DESC
LIMIT 1;
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_espertiBene(IN in_bene INT)
BEGIN
	SELECT * FROM esperti e
    WHERE e.campo = (
		SELECT b.tipo 
		FROM beni b
		WHERE in_bene = b.idDeposito)
	ORDER BY e.costo ASC;
END $$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE sp_tipoPiuVenduto()
BEGIN
	SELECT b.tipo, count(*) as num FROM beni b
    INNER JOIN transazioni t 
		ON t.prodotto = b.idDeposito
	INNER JOIN scontrini s
		ON s.numeroScontrino = t.scontrino
	WHERE s.tipo LIKE 'V' AND s.dataOra > DATE_SUB(NOW(), INTERVAL 1 MONTH)
    GROUP BY b.tipo
    ORDER BY num DESC
    LIMIT 1;
END $$
DELIMITER ;

CREATE VIEW view_prodotti AS
    SELECT descrizione, tipo, prezzo 
    FROM beni
    WHERE acquisito IS TRUE;

CREATE VIEW view_scontrini AS
    SELECT s.numeroScontrino, sum(t.importo) as totale, s.tipo
    FROM scontrini s
	INNER JOIN transazioni t
		ON s.numeroScontrino = t.scontrino
	GROUP BY s.numeroScontrino;
    
SET FOREIGN_KEY_CHECKS=0;
INSERT INTO esperti VALUES('+39 23403421', 'giovanni.esposito@outlook.com', 'Giovanni', 'Esposito', 'Collane', 25.75);
INSERT INTO esperti VALUES('+39 04191883', 'amerigo.augusto@hotmail.it', 'Amerigo', 'Augusto', 'Argento', 30.94);
INSERT INTO esperti VALUES('+39 52700958', 'giacomo.fontana@dundermifflin.com', 'Giacomo', 'Fontana', 'Musica', 22.01);        
INSERT INTO esperti VALUES('+39 40972876', 'kenny.topolini@dundermifflin.com', 'Kenny', 'Topolini', 'Gioielli', 30.18);        
INSERT INTO esperti VALUES('+39 77367952', 'mariano.gold@dundermifflin.com', 'Mariano', 'Gold', 'Argento', 47.15);
INSERT INTO esperti VALUES('+39 39673579', 'pamela.rossoni@dundermifflin.com', 'Pamela', 'Rossoni', 'Musica', 47.66);
INSERT INTO esperti VALUES('+39 33371966', 'annabelle.galilei@dundermifflin.com', 'Annabelle', 'Galilei', 'Gioielli', 17.32);  
INSERT INTO esperti VALUES('+39 95530481', 'rick.greco@dundermifflin.com', 'Rick', 'Greco', 'Videogiochi', 16.3);
INSERT INTO esperti VALUES('+39 53346868', 'gregory.lauro@hotmail.it', 'Gregory', 'Lauro', 'Oro', 23.35);
INSERT INTO esperti VALUES('+39 27933974', 'felicia.grandi@dundermifflin.com', 'Felicia', 'Grandi', 'Elettronica', 9.64);      
INSERT INTO esperti VALUES('+39 62790173', 'jane.gatti@outlook.com', 'Jane', 'Gatti', 'Armi', 17.2);
INSERT INTO esperti VALUES('+39 95720384', 'johnny.gatto@dundermifflin.com', 'Johnny', 'Gatto', 'Oro', 44.39);
INSERT INTO esperti VALUES('+39 24698683', 'renato.neri@outlook.com', 'Renato', 'Neri', 'Gioielli', 1.4);
INSERT INTO esperti VALUES('+39 18350889', 'johnny.jagger@outlook.com', 'Johnny', 'Jagger', 'Elettronica', 6.77);
INSERT INTO esperti VALUES('+39 73122373', 'francesco.alighieri@hotmail.it', 'Francesco', 'Alighieri', 'Monete', 45.56);       
INSERT INTO esperti VALUES('+39 39878581', 'enrico.franco@dundermifflin.com', 'Enrico', 'Franco', 'Musica', 43.33);
INSERT INTO esperti VALUES('+39 62577675', 'petra.augusto@outlook.com', 'Petra', 'Augusto', 'Motori', 28.57);
INSERT INTO esperti VALUES('+39 59618616', 'francesca.augusto@outlook.com', 'Francesca', 'Augusto', 'Oro', 11.75);
INSERT INTO esperti VALUES('+39 35524650', 'annabelle.ferrari@yahoo.com', 'Annabelle', 'Ferrari', 'Motori', 37.22);
INSERT INTO esperti VALUES('+39 76581278', 'michael.miele@dundermifflin.com', 'Michael', 'Miele', 'Libri', 44.47);
INSERT INTO esperti VALUES('+39 29395999', 'carlo.scott@outlook.com', 'Carlo', 'Scott', 'Argento', 22.4);
INSERT INTO esperti VALUES('+39 94946266', 'ludovica.moretti@gmail.com', 'Ludovica', 'Moretti', 'Collane', 9.02);
INSERT INTO esperti VALUES('+39 13431019', 'riccardo.ferretti@dundermifflin.com', 'Riccardo', 'Ferretti', 'Collane', 18.67);   
INSERT INTO esperti VALUES('+39 78039697', 'michael.basettoni@gmail.com', 'Michael', 'Basettoni', 'Armi', 29.57);
INSERT INTO esperti VALUES('+39 11565362', 'rene.milano@dundermifflin.com', 'Rene', 'Milano', 'Elettronica', 10.55);
INSERT INTO esperti VALUES('+39 18411751', 'mariano.marino@hotmail.it', 'Mariano', 'Marino', 'Vestiti', 4.26);
INSERT INTO esperti VALUES('+39 63395873', 'angelo.lamborghini@yahoo.com', 'Angelo', 'Lamborghini', 'Armi', 19.4);
INSERT INTO esperti VALUES('+39 62430483', 'henry.grande@gmail.com', 'Henry', 'Grande', 'Libri', 35.48);
INSERT INTO esperti VALUES('+39 01057152', 'violetta.conte@yahoo.com', 'Violetta', 'Conte', 'Elettronica', 26.54);
INSERT INTO esperti VALUES('+39 78518951', 'felicia.starr@gmail.com', 'Felicia', 'Starr', 'Oro', 40.77);
INSERT INTO esperti VALUES('+39 21380020', 'annabelle.monti@yahoo.com', 'Annabelle', 'Monti', 'Videogiochi', 3.21);
INSERT INTO esperti VALUES('+39 78854097', 'violetta.bruno@dundermifflin.com', 'Violetta', 'Bruno', 'Libri', 15.13);
INSERT INTO esperti VALUES('+39 44438937', 'angelo.gentile@outlook.com', 'Angelo', 'Gentile', 'Pietre preziose', 36.01);       
INSERT INTO esperti VALUES('+39 99820747', 'kenny.milano@hotmail.it', 'Kenny', 'Milano', 'Memorabilia', 28.97);
INSERT INTO esperti VALUES('+39 58564300', 'henry.draghi@hotmail.it', 'Henry', 'Draghi', 'Monete', 28.99);
INSERT INTO esperti VALUES('+39 60693279', 'beatrice.longo@gmail.com', 'Beatrice', 'Longo', 'Vestiti', 35.58);
INSERT INTO esperti VALUES('+39 61489701', 'giuseppe.grande@hotmail.it', 'Giuseppe', 'Grande', 'Orologi', 17.03);
INSERT INTO esperti VALUES('+39 95258856', 'cesare.alighieri@hotmail.it', 'Cesare', 'Alighieri', 'Orologi', 14.9);
INSERT INTO esperti VALUES('+39 23754873', 'alan.smith@dundermifflin.com', 'Alan', 'Smith', 'Armi', 25.8);
INSERT INTO esperti VALUES('+39 31571812', 'angelo.russo@yahoo.com', 'Angelo', 'Russo', 'Argento', 12.14);
INSERT INTO esperti VALUES('+39 82225663', 'angelo.lamborghini@hotmail.it', 'Angelo', 'Lamborghini', 'Vestiti', 23.47);        
INSERT INTO esperti VALUES('+39 28857172', 'alice.harrison@outlook.com', 'Alice', 'Harrison', 'Memorabilia', 46.58);
INSERT INTO esperti VALUES('+39 71980864', 'henry.greco@gmail.com', 'Henry', 'Greco', 'Pietre preziose', 19.79);
INSERT INTO esperti VALUES('+39 03674575', 'alan.scavo@outlook.com', 'Alan', 'Scavo', 'Orologi', 9.47);
INSERT INTO esperti VALUES('+39 77239121', 'stefano.bravi@gmail.com', 'Stefano', 'Bravi', 'Quadri', 7.38);
INSERT INTO esperti VALUES('+39 83181743', 'paolo.pennac@yahoo.com', 'Paolo', 'Pennac', 'Monete', 20.37);
INSERT INTO esperti VALUES('+39 22446160', 'giuseppe.grandi@hotmail.it', 'Giuseppe', 'Grandi', 'Libri', 22.69);
INSERT INTO esperti VALUES('+39 01549070', 'alan.franco@gmail.com', 'Alan', 'Franco', 'Memorabilia', 15.49);
INSERT INTO esperti VALUES('+39 21488689', 'claudia.grandi@yahoo.com', 'Claudia', 'Grandi', 'Quadri', 37.99);
INSERT INTO esperti VALUES('+39 26456139', 'daniele.lauro@yahoo.com', 'Daniele', 'Lauro', 'Gioielli', 5.0);
INSERT INTO debitori VALUES(0, 'Alan', 'Monti', '+39 34057217', 'alan.monti@hotmail.it');
INSERT INTO debitori VALUES(0, 'Riccardo', 'Grande', '+39 86723738', 'riccardo.grande@hotmail.it');
INSERT INTO debitori VALUES(0, 'Chiara', 'Nerone', '+39 85519328', 'chiara.nerone@gmail.com');
INSERT INTO debitori VALUES(0, 'Tommaso', 'Annunziato', '+39 16432391', 'tommaso.annunziato@dundermifflin.com');
INSERT INTO debitori VALUES(0, 'Diana', 'Ferrari', '+39 28229504', 'diana.ferrari@dundermifflin.com');
INSERT INTO debitori VALUES(0, 'Rene', 'DeSantis', '+39 00526675', 'rene.desantis@hotmail.it');
INSERT INTO debitori VALUES(0, 'Dwight', 'Grandi', '+39 51268001', 'dwight.grandi@dundermifflin.com');
INSERT INTO debitori VALUES(0, 'Oscar', 'Lamborghini', '+39 14996201', 'oscar.lamborghini@yahoo.com');
INSERT INTO debitori VALUES(0, 'Carlo', 'Mieli', '+39 75908574', 'carlo.mieli@dundermifflin.com');
INSERT INTO debitori VALUES(0, 'Cesare', 'Scott', '+39 89066663', 'cesare.scott@yahoo.com');
INSERT INTO debitori VALUES(0, 'Chiara', 'Collina', '+39 95482842', 'chiara.collina@outlook.com');
INSERT INTO debitori VALUES(0, 'Rene', 'Foscolo', '+39 88297804', 'rene.foscolo@outlook.com');
INSERT INTO debitori VALUES(0, 'Carlo', 'Leone', '+39 36833661', 'carlo.leone@yahoo.com');
INSERT INTO debitori VALUES(0, 'Enrico', 'Fermi', '+39 32561567', 'enrico.fermi@yahoo.com');
INSERT INTO debitori VALUES(0, 'Anna', 'Piano', '+39 69582392', 'anna.piano@hotmail.it');
INSERT INTO debitori VALUES(0, 'Angelo', 'Galilei', '+39 63454864', 'angelo.galilei@dundermifflin.com');
INSERT INTO debitori VALUES(0, 'Carlo', 'Buttazzoni', '+39 44101473', 'carlo.buttazzoni@dundermifflin.com');
INSERT INTO debitori VALUES(0, 'Claudia', 'Nerone', '+39 28881178', 'claudia.nerone@yahoo.com');
INSERT INTO debitori VALUES(0, 'Roberto', 'Grandi', '+39 23195637', 'roberto.grandi@dundermifflin.com');
INSERT INTO debitori VALUES(0, 'Jack', 'House', '+39 11377983', 'jack.house@hotmail.it');
INSERT INTO debitori VALUES(0, 'Francesca', 'Alighieri', '+39 51681840', 'francesca.alighieri@outlook.com');
INSERT INTO debitori VALUES(0, 'Jim', 'Augusto', '+39 67081325', 'jim.augusto@yahoo.com');
INSERT INTO debitori VALUES(0, 'Les', 'Grande', '+39 98769477', 'les.grande@yahoo.com');
INSERT INTO debitori VALUES(0, 'Elena', 'Scavo', '+39 01212609', 'elena.scavo@yahoo.com');
INSERT INTO debitori VALUES(0, 'Amilcare', 'Nerone', '+39 16005454', 'amilcare.nerone@gmail.com');
INSERT INTO debitori VALUES(0, 'Les', 'Gallo', '+39 33335107', 'les.gallo@hotmail.it');
INSERT INTO debitori VALUES(0, 'Maria', 'Mieli', '+39 87976935', 'maria.mieli@gmail.com');
INSERT INTO debitori VALUES(0, 'Chad', 'Paperini', '+39 86573832', 'chad.paperini@gmail.com');
INSERT INTO debitori VALUES(0, 'Anna', 'Londra', '+39 56648093', 'anna.londra@gmail.com');
INSERT INTO debitori VALUES(0, 'Lorenzo', 'Bravi', '+39 04571928', 'lorenzo.bravi@dundermifflin.com');
INSERT INTO debitori VALUES(0, 'Michael', 'Greco', '+39 00715703', 'michael.greco@outlook.com');
INSERT INTO debitori VALUES(0, 'Tommaso', 'Deledda', '+39 89101367', 'tommaso.deledda@outlook.com');
INSERT INTO debitori VALUES(0, 'Daniele', 'Costa', '+39 74421425', 'daniele.costa@yahoo.com');
INSERT INTO debitori VALUES(0, 'Diana', 'Starr', '+39 53758574', 'diana.starr@gmail.com');
INSERT INTO debitori VALUES(0, 'Michael', 'LaRochelle', '+39 80848868', 'michael.larochelle@outlook.com');
INSERT INTO debitori VALUES(0, 'Gregory', 'Ferro', '+39 73294411', 'gregory.ferro@outlook.com');
INSERT INTO debitori VALUES(0, 'Renato', 'Romano', '+39 84631683', 'renato.romano@outlook.com');
INSERT INTO debitori VALUES(0, 'Alan', 'Sette', '+39 09946851', 'alan.sette@outlook.com');
INSERT INTO debitori VALUES(0, 'Sara', 'Monti', '+39 34159252', 'sara.monti@hotmail.it');
INSERT INTO debitori VALUES(0, 'Kenny', 'Bravo', '+39 27595229', 'kenny.bravo@dundermifflin.com');
INSERT INTO debitori VALUES(0, 'Stanis', 'House', '+39 28374350', 'stanis.house@gmail.com');
INSERT INTO debitori VALUES(0, 'Jane', 'Milano', '+39 71562888', 'jane.milano@outlook.com');
INSERT INTO debitori VALUES(0, 'Chiara', 'Ferrero', '+39 70912559', 'chiara.ferrero@hotmail.it');
INSERT INTO debitori VALUES(0, 'Daniele', 'Russo', '+39 81535127', 'daniele.russo@dundermifflin.com');
INSERT INTO debitori VALUES(0, 'James', 'White', '+39 69421813', 'james.white@hotmail.it');
INSERT INTO debitori VALUES(0, 'Enrico', 'Rossoni', '+39 41378072', 'enrico.rossoni@outlook.com');
INSERT INTO debitori VALUES(0, 'Maria', 'Greco', '+39 14784859', 'maria.greco@yahoo.com');
INSERT INTO debitori VALUES(0, 'Giovanni', 'Amici', '+39 45370679', 'giovanni.amici@hotmail.it');
INSERT INTO debitori VALUES(0, 'Alice', 'Verdi', '+39 10626580', 'alice.verdi@hotmail.it');
INSERT INTO debitori VALUES(0, 'Chad', 'Foscolo', '+39 33638262', 'chad.foscolo@hotmail.it');
INSERT INTO debitori VALUES(0, 'Joe', 'Bianchi', '+39 14492657', 'joe.bianchi@hotmail.it');
INSERT INTO debitori VALUES(0, 'Petra', 'Verdi', '+39 21254984', 'petra.verdi@yahoo.com');
INSERT INTO debitori VALUES(0, 'Valentino', 'Smith', '+39 59900434', 'valentino.smith@hotmail.it');
INSERT INTO debitori VALUES(0, 'Felicia', 'Heard', '+39 53591840', 'felicia.heard@dundermifflin.com');
INSERT INTO debitori VALUES(0, 'Beatrice', 'DeSantis', '+39 74558652', 'beatrice.desantis@yahoo.com');
INSERT INTO debitori VALUES(0, 'Chad', 'Alberti', '+39 38503733', 'chad.alberti@gmail.com');
INSERT INTO debitori VALUES(0, 'Andrea', 'Scott', '+39 07781794', 'andrea.scott@outlook.com');
INSERT INTO debitori VALUES(0, 'Walter', 'Bravi', '+39 73264788', 'walter.bravi@yahoo.com');
INSERT INTO debitori VALUES(0, 'Joe', 'Torino', '+39 90299906', 'joe.torino@dundermifflin.com');
INSERT INTO debitori VALUES(0, 'Anna', 'Mieli', '+39 64671618', 'anna.mieli@outlook.com');
INSERT INTO debitori VALUES(0, 'Stanis', 'Harrison', '+39 58658856', 'stanis.harrison@outlook.com');
INSERT INTO debitori VALUES(0, 'Mattia', 'Piano', '+39 01653533', 'mattia.piano@hotmail.it');
INSERT INTO debitori VALUES(0, 'Amilcare', 'Leone', '+39 03344675', 'amilcare.leone@hotmail.it');
INSERT INTO debitori VALUES(0, 'Walter', 'Violini', '+39 35041179', 'walter.violini@hotmail.it');
INSERT INTO debitori VALUES(0, 'Giacomo', 'Alighieri', '+39 68678452', 'giacomo.alighieri@hotmail.it');
INSERT INTO debitori VALUES(0, 'Stanis', 'Rossi', '+39 00384001', 'stanis.rossi@gmail.com');
INSERT INTO debitori VALUES(0, 'Mariano', 'Mieli', '+39 78325154', 'mariano.mieli@yahoo.com');
INSERT INTO debitori VALUES(0, 'Henry', 'Paperini', '+39 94283876', 'henry.paperini@dundermifflin.com');
INSERT INTO debitori VALUES(0, 'Andrea', 'Bastianich', '+39 98145488', 'andrea.bastianich@hotmail.it');
INSERT INTO debitori VALUES(0, 'Dwight', 'Grandi', '+39 29311706', 'dwight.grandi@gmail.com');
INSERT INTO debitori VALUES(0, 'Ludovica', 'Corte', '+39 52443527', 'ludovica.corte@gmail.com');
INSERT INTO debitori VALUES(0, 'Lorenzo', 'Paperini', '+39 46460647', 'lorenzo.paperini@gmail.com');
INSERT INTO debitori VALUES(0, 'Dwight', 'Paperini', '+39 36256558', 'dwight.paperini@dundermifflin.com');
INSERT INTO debitori VALUES(0, 'Amilcare', 'Franco', '+39 38581671', 'amilcare.franco@gmail.com');
INSERT INTO debitori VALUES(0, 'Diana', 'Carli', '+39 47438186', 'diana.carli@yahoo.com');
INSERT INTO debitori VALUES(0, 'Stefano', 'Fontana', '+39 24975027', 'stefano.fontana@hotmail.it');
INSERT INTO debitori VALUES(0, 'Kenny', 'Lauro', '+39 14237192', 'kenny.lauro@outlook.com');
INSERT INTO debitori VALUES(0, 'Mattia', 'Miele', '+39 72369453', 'mattia.miele@outlook.com');
INSERT INTO debitori VALUES(0, 'Dwight', 'Monti', '+39 97816005', 'dwight.monti@dundermifflin.com');
INSERT INTO debitori VALUES(0, 'Amerigo', 'Londra', '+39 86460803', 'amerigo.londra@outlook.com');
INSERT INTO dipendenti VALUES(0, 'Walter', 'White', 'Vendite');
INSERT INTO dipendenti VALUES(0, 'Les', 'Foscolo', 'Pegni');
INSERT INTO dipendenti VALUES(0, 'Harry', 'Ferro', 'HR');
INSERT INTO dipendenti VALUES(0, 'Paolo', 'Gatti', 'Vendite');
INSERT INTO dipendenti VALUES(0, 'Cesare', 'Ferrero', 'Pegni');
INSERT INTO dipendenti VALUES(0, 'Nello', 'Gold', 'HR');
INSERT INTO dipendenti VALUES(0, 'Andrea', 'LaRochelle', 'HR');
INSERT INTO dipendenti VALUES(0, 'Henry', 'Corte', 'Vendite');
INSERT INTO dipendenti VALUES(0, 'Johnny', 'Bianchi', 'HR');
INSERT INTO dipendenti VALUES(0, 'Stanis', 'Rossi', 'Vendite');
INSERT INTO dipendenti VALUES(0, 'Jack', 'Colombo', 'Vendite');
INSERT INTO dipendenti VALUES(0, 'Henry', 'Ferrari', 'HR');
INSERT INTO dipendenti VALUES(0, 'Beatrice', 'Ferretti', 'Vendite');
INSERT INTO dipendenti VALUES(0, 'Alessia', 'Russo', 'Pegni');
INSERT INTO dipendenti VALUES(0, 'Anna', 'Conte', 'Pegni');
INSERT INTO dipendenti VALUES(0, 'Kyle', 'Violini', 'HR');
INSERT INTO dipendenti VALUES(0, 'Johnny', 'Bruno', 'Pegni');
INSERT INTO dipendenti VALUES(0, 'Alessia', 'Greco', 'Pegni');
INSERT INTO dipendenti VALUES(0, 'Claudia', 'Berlusconi', 'Vendite');
INSERT INTO dipendenti VALUES(0, 'Chad', 'Berlusconi', 'Vendite');
INSERT INTO scontrini VALUES(0, '2022-03-09', 'V', 18);
INSERT INTO scontrini VALUES(0, '2022-03-16', 'A', 11);
INSERT INTO scontrini VALUES(0, '2022-04-07', 'A', 10);
INSERT INTO scontrini VALUES(0, '2022-02-04', 'V', 12);
INSERT INTO scontrini VALUES(0, '2022-02-24', 'A', 11);
INSERT INTO scontrini VALUES(0, '2022-03-09', 'V', 5);
INSERT INTO scontrini VALUES(0, '2022-02-23', 'A', 18);
INSERT INTO scontrini VALUES(0, '2022-01-17', 'A', 15);
INSERT INTO scontrini VALUES(0, '2022-02-12', 'A', 7);
INSERT INTO scontrini VALUES(0, '2022-03-24', 'A', 12);
INSERT INTO scontrini VALUES(0, '2022-01-23', 'A', 11);
INSERT INTO scontrini VALUES(0, '2022-03-11', 'A', 14);
INSERT INTO scontrini VALUES(0, '2022-01-15', 'V', 14);
INSERT INTO scontrini VALUES(0, '2022-01-26', 'A', 10);
INSERT INTO scontrini VALUES(0, '2022-01-11', 'A', 8);
INSERT INTO scontrini VALUES(0, '2022-04-24', 'A', 12);
INSERT INTO scontrini VALUES(0, '2022-03-12', 'V', 16);
INSERT INTO scontrini VALUES(0, '2022-01-25', 'A', 10);
INSERT INTO scontrini VALUES(0, '2022-03-28', 'V', 19);
INSERT INTO scontrini VALUES(0, '2022-01-30', 'A', 8);
INSERT INTO scontrini VALUES(0, '2022-03-01', 'A', 14);
INSERT INTO scontrini VALUES(0, '2022-01-10', 'A', 3);
INSERT INTO scontrini VALUES(0, '2022-04-06', 'A', 12);
INSERT INTO scontrini VALUES(0, '2022-03-23', 'A', 16);
INSERT INTO scontrini VALUES(0, '2022-02-13', 'A', 2);
INSERT INTO scontrini VALUES(0, '2022-02-02', 'V', 7);
INSERT INTO scontrini VALUES(0, '2022-01-08', 'A', 17);
INSERT INTO scontrini VALUES(0, '2022-03-24', 'A', 17);
INSERT INTO scontrini VALUES(0, '2022-01-13', 'A', 3);
INSERT INTO scontrini VALUES(0, '2022-04-30', 'A', 4);
INSERT INTO scontrini VALUES(0, '2022-02-10', 'A', 11);
INSERT INTO scontrini VALUES(0, '2022-01-02', 'A', 5);
INSERT INTO scontrini VALUES(0, '2022-02-22', 'A', 5);
INSERT INTO scontrini VALUES(0, '2022-04-26', 'V', 15);
INSERT INTO scontrini VALUES(0, '2022-01-19', 'V', 7);
INSERT INTO scontrini VALUES(0, '2022-01-25', 'A', 6);
INSERT INTO scontrini VALUES(0, '2022-04-17', 'A', 6);
INSERT INTO scontrini VALUES(0, '2022-01-23', 'A', 4);
INSERT INTO scontrini VALUES(0, '2022-02-09', 'A', 10);
INSERT INTO scontrini VALUES(0, '2022-01-30', 'V', 5);
INSERT INTO scontrini VALUES(0, '2022-03-04', 'V', 11);
INSERT INTO scontrini VALUES(0, '2022-01-15', 'A', 5);
INSERT INTO scontrini VALUES(0, '2022-02-04', 'A', 12);
INSERT INTO scontrini VALUES(0, '2022-01-21', 'V', 3);
INSERT INTO scontrini VALUES(0, '2022-03-30', 'A', 15);
INSERT INTO scontrini VALUES(0, '2022-03-09', 'A', 9);
INSERT INTO scontrini VALUES(0, '2022-02-01', 'A', 13);
INSERT INTO scontrini VALUES(0, '2022-03-04', 'A', 6);
INSERT INTO scontrini VALUES(0, '2022-03-09', 'V', 14);
INSERT INTO scontrini VALUES(0, '2022-02-08', 'V', 18);
INSERT INTO scontrini VALUES(0, '2022-01-28', 'A', 2);
INSERT INTO scontrini VALUES(0, '2022-03-26', 'A', 8);
INSERT INTO scontrini VALUES(0, '2022-03-15', 'A', 1);
INSERT INTO scontrini VALUES(0, '2022-02-18', 'A', 5);
INSERT INTO scontrini VALUES(0, '2022-03-07', 'A', 7);
INSERT INTO scontrini VALUES(0, '2022-04-10', 'V', 19);
INSERT INTO scontrini VALUES(0, '2022-04-10', 'A', 5);
INSERT INTO scontrini VALUES(0, '2022-01-19', 'V', 18);
INSERT INTO scontrini VALUES(0, '2022-02-11', 'A', 19);
INSERT INTO scontrini VALUES(0, '2022-01-02', 'A', 20);
INSERT INTO scontrini VALUES(0, '2022-04-26', 'V', 1);
INSERT INTO scontrini VALUES(0, '2022-03-01', 'V', 10);
INSERT INTO scontrini VALUES(0, '2022-01-05', 'A', 17);
INSERT INTO scontrini VALUES(0, '2022-03-14', 'A', 14);
INSERT INTO scontrini VALUES(0, '2022-01-05', 'A', 2);
INSERT INTO scontrini VALUES(0, '2022-01-31', 'V', 10);
INSERT INTO scontrini VALUES(0, '2022-04-13', 'A', 20);
INSERT INTO scontrini VALUES(0, '2022-01-26', 'V', 16);
INSERT INTO scontrini VALUES(0, '2022-03-07', 'A', 18);
INSERT INTO scontrini VALUES(0, '2022-03-27', 'A', 6);
INSERT INTO scontrini VALUES(0, '2022-04-28', 'V', 13);
INSERT INTO scontrini VALUES(0, '2022-01-25', 'A', 7);
INSERT INTO scontrini VALUES(0, '2022-04-14', 'A', 18);
INSERT INTO scontrini VALUES(0, '2022-03-27', 'A', 4);
INSERT INTO scontrini VALUES(0, '2022-04-05', 'A', 4);
INSERT INTO scontrini VALUES(0, '2022-04-28', 'A', 5);
INSERT INTO scontrini VALUES(0, '2022-02-20', 'A', 2);
INSERT INTO scontrini VALUES(0, '2022-04-16', 'V', 19);
INSERT INTO scontrini VALUES(0, '2022-01-12', 'A', 2);
INSERT INTO scontrini VALUES(0, '2022-04-18', 'V', 9);
INSERT INTO scontrini VALUES(0, '2022-02-08', 'A', 5);
INSERT INTO scontrini VALUES(0, '2022-04-30', 'A', 16);
INSERT INTO scontrini VALUES(0, '2022-04-18', 'A', 10);
INSERT INTO scontrini VALUES(0, '2022-03-23', 'V', 20);
INSERT INTO scontrini VALUES(0, '2022-01-04', 'A', 15);
INSERT INTO scontrini VALUES(0, '2022-02-23', 'A', 20);
INSERT INTO scontrini VALUES(0, '2022-03-07', 'A', 19);
INSERT INTO scontrini VALUES(0, '2022-04-03', 'A', 17);
INSERT INTO scontrini VALUES(0, '2022-04-01', 'A', 5);
INSERT INTO scontrini VALUES(0, '2022-01-11', 'V', 8);
INSERT INTO scontrini VALUES(0, '2022-03-07', 'A', 15);
INSERT INTO scontrini VALUES(0, '2022-02-20', 'A', 17);
INSERT INTO scontrini VALUES(0, '2022-02-21', 'A', 13);
INSERT INTO scontrini VALUES(0, '2022-01-18', 'A', 14);
INSERT INTO scontrini VALUES(0, '2022-01-06', 'A', 15);
INSERT INTO scontrini VALUES(0, '2022-03-29', 'V', 9);
INSERT INTO scontrini VALUES(0, '2022-04-20', 'A', 18);
INSERT INTO scontrini VALUES(0, '2022-02-03', 'V', 20);
INSERT INTO scontrini VALUES(0, '2022-01-13', 'V', 13);
INSERT INTO scontrini VALUES(0, '2022-01-04', 'A', 8);
INSERT INTO prestiti VALUES(0, '2022-03-06', 116, 16547.65975997617, 1.9658464736784809, 28, 44, 19);
INSERT INTO prestiti VALUES(0, '2022-01-30', 40, 49997.38601142356, 1.3361188741164853, 0, 66, 8);
INSERT INTO prestiti VALUES(0, '2022-03-19', 144, 24426.81300065087, 3.238729029913917, 0, 23, 3);
INSERT INTO prestiti VALUES(0, '2022-02-16', 118, 17133.841363816286, 5.806161834510992, 38, 27, 11);
INSERT INTO prestiti VALUES(0, '2022-02-26', 39, 3582.3586587951636, 9.86446757247959, 0, 33, 5);
INSERT INTO prestiti VALUES(0, '2022-04-14', 126, 46620.76243395109, 1.8496989547195009, 0, 76, 7);
INSERT INTO prestiti VALUES(0, '2022-01-20', 63, 10043.872904452228, 7.862625962963172, 0, 33, 7);
INSERT INTO prestiti VALUES(0, '2022-03-17', 167, 12836.50514123739, 5.609053854155771, 0, 20, 5);
INSERT INTO prestiti VALUES(0, '2022-01-18', 105, 10217.835180573, 6.090306025305884, 0, 65, 10);
INSERT INTO prestiti VALUES(0, '2022-04-13', 144, 242.05600338534137, 9.804083482989594, 14, 53, 6);
INSERT INTO prestiti VALUES(0, '2022-01-24', 171, 6289.303507091378, 5.794928068769181, 0, 3, 17);
INSERT INTO prestiti VALUES(0, '2022-02-13', 5, 25918.426331164315, 8.783142749351466, 0, 53, 11);
INSERT INTO prestiti VALUES(0, '2022-01-26', 1, 39719.55016649929, 1.0255225673697352, 19, 9, 4);
INSERT INTO prestiti VALUES(0, '2022-03-03', 127, 30733.61988049926, 4.081165788671996, 0, 27, 2);
INSERT INTO prestiti VALUES(0, '2022-02-18', 177, 47701.552231112095, 1.0052571690722962, 0, 74, 19);
INSERT INTO prestiti VALUES(0, '2022-03-19', 173, 20728.810386030018, 2.8876285962554373, 0, 37, 3);
INSERT INTO prestiti VALUES(0, '2022-02-09', 131, 8410.917560606673, 5.900337986221987, 0, 36, 11);
INSERT INTO prestiti VALUES(0, '2022-03-17', 23, 30745.37658384317, 2.68252898323943, 0, 7, 17);
INSERT INTO prestiti VALUES(0, '2022-02-17', 36, 25094.31461039264, 3.384460872142227, 0, 30, 13);
INSERT INTO prestiti VALUES(0, '2022-03-12', 131, 32762.690582024243, 9.49041433064951, 0, 67, 13);
INSERT INTO prestiti VALUES(0, '2022-01-11', 76, 47232.28528501935, 4.435592377766443, 0, 13, 17);
INSERT INTO prestiti VALUES(0, '2022-01-28', 8, 8677.43667928062, 8.51869146423067, 0, 19, 1);
INSERT INTO prestiti VALUES(0, '2022-03-28', 151, 29080.554006496204, 2.842368955259538, 0, 21, 9);
INSERT INTO prestiti VALUES(0, '2022-03-18', 148, 20000.988854664392, 8.761887844112373, 0, 16, 13);
INSERT INTO prestiti VALUES(0, '2022-01-22', 9, 21643.03103343315, 3.6349971274224107, 0, 60, 17);
INSERT INTO prestiti VALUES(0, '2022-01-16', 5, 31745.245269679504, 2.6775778652457567, 0, 41, 15);
INSERT INTO prestiti VALUES(0, '2022-02-16', 144, 17749.69406126686, 4.6369781204783065, 24, 57, 7);
INSERT INTO prestiti VALUES(0, '2022-03-06', 47, 2767.7351201991023, 3.597339633102643, 0, 77, 1);
INSERT INTO prestiti VALUES(0, '2022-03-31', 67, 40909.56490213353, 2.237644793612026, 14, 12, 3);
INSERT INTO prestiti VALUES(0, '2022-04-15', 60, 9383.037822852682, 6.19544077418152, 0, 30, 16);
INSERT INTO prestiti VALUES(0, '2022-02-16', 39, 24540.856798242978, 8.562351501365635, 0, 26, 6);
INSERT INTO prestiti VALUES(0, '2022-01-26', 155, 30129.11138085622, 7.514087326809177, 0, 16, 17);
INSERT INTO prestiti VALUES(0, '2022-03-29', 84, 46119.33526154629, 4.918000459480513, 0, 42, 13);
INSERT INTO prestiti VALUES(0, '2022-01-10', 43, 19801.416954171953, 2.765866320952907, 0, 20, 1);
INSERT INTO prestiti VALUES(0, '2022-01-17', 42, 29837.141261973313, 7.507153023279517, 0, 58, 1);
INSERT INTO prestiti VALUES(0, '2022-04-02', 21, 10052.84097609034, 7.451216531188029, 0, 20, 9);
INSERT INTO prestiti VALUES(0, '2022-03-24', 178, 41196.9165418597, 3.4533372695356994, 0, 11, 3);
INSERT INTO prestiti VALUES(0, '2022-01-08', 4, 14156.022481659682, 3.3795224538985984, 0, 27, 3);
INSERT INTO prestiti VALUES(0, '2022-04-21', 151, 37706.529592882696, 4.449329086284788, 39, 53, 10);
INSERT INTO prestiti VALUES(0, '2022-03-09', 146, 40797.80263565532, 7.30152286487832, 0, 25, 19);
INSERT INTO prestiti VALUES(0, '2022-02-07', 47, 30998.568098771946, 8.605539616104402, 17, 44, 10);
INSERT INTO prestiti VALUES(0, '2022-03-31', 75, 9804.132413015352, 4.2562132858616355, 0, 48, 18);
INSERT INTO prestiti VALUES(0, '2022-02-05', 31, 10448.33487489026, 5.148853959684412, 0, 62, 3);
INSERT INTO prestiti VALUES(0, '2022-01-13', 139, 1147.7213089629731, 6.927737903959191, 0, 60, 5);
INSERT INTO prestiti VALUES(0, '2022-02-08', 159, 48584.77032650735, 5.0146393941779355, 0, 76, 1);
INSERT INTO prestiti VALUES(0, '2022-01-27', 121, 48617.99493894927, 6.0368722753609205, 0, 60, 2);
INSERT INTO prestiti VALUES(0, '2022-02-22', 21, 15641.613587170388, 6.185357034406234, 0, 53, 10);
INSERT INTO prestiti VALUES(0, '2022-04-14', 41, 42267.60304106239, 4.179967520452711, 0, 60, 4);
INSERT INTO prestiti VALUES(0, '2022-03-24', 149, 42219.0781693903, 8.387541873956515, 16, 26, 12);
INSERT INTO prestiti VALUES(0, '2022-01-24', 66, 30706.924563714078, 7.088550625369688, 22, 49, 6);
INSERT INTO prestiti VALUES(0, '2022-02-27', 34, 1128.945536755936, 1.9020678922588468, 0, 71, 16);
INSERT INTO prestiti VALUES(0, '2022-05-01', 32, 14373.331602142009, 1.633138788670891, 35, 13, 13);
INSERT INTO prestiti VALUES(0, '2022-01-18', 167, 6527.426419672882, 5.049166526481318, 0, 67, 6);
INSERT INTO prestiti VALUES(0, '2022-04-04', 22, 40440.55741385528, 4.424211136213224, 34, 11, 6);
INSERT INTO prestiti VALUES(0, '2022-03-16', 125, 10411.628800524539, 4.5339796530905385, 0, 2, 14);
INSERT INTO prestiti VALUES(0, '2022-04-15', 170, 29911.74431634847, 7.052081921542335, 0, 20, 5);
INSERT INTO prestiti VALUES(0, '2022-02-22', 139, 11420.428980927807, 5.797599029496757, 0, 48, 12);
INSERT INTO prestiti VALUES(0, '2022-03-19', 129, 19399.473196976247, 4.350244118209037, 0, 12, 4);
INSERT INTO prestiti VALUES(0, '2022-04-01', 123, 11340.514581226464, 5.875064233379632, 37, 79, 6);
INSERT INTO prestiti VALUES(0, '2022-04-19', 154, 39319.338101731206, 4.172890092804692, 0, 22, 8);
INSERT INTO prestiti VALUES(0, '2022-04-09', 104, 13036.131637075443, 7.473075474239592, 0, 43, 16);
INSERT INTO prestiti VALUES(0, '2022-01-31', 63, 3903.815333860318, 7.890768130570274, 0, 8, 17);
INSERT INTO prestiti VALUES(0, '2022-03-21', 173, 41628.54253399301, 4.526639760946995, 0, 35, 7);
INSERT INTO prestiti VALUES(0, '2022-01-29', 165, 44900.55287421603, 7.724562463902343, 0, 29, 20);
INSERT INTO prestiti VALUES(0, '2022-04-08', 75, 735.482755160001, 2.860789859719454, 0, 5, 20);
INSERT INTO prestiti VALUES(0, '2022-01-13', 19, 3863.7882766142084, 1.0352645271058063, 0, 73, 4);
INSERT INTO prestiti VALUES(0, '2022-01-11', 156, 20903.945918989815, 3.6377667512637135, 0, 45, 11);
INSERT INTO prestiti VALUES(0, '2022-03-18', 79, 13839.18956582035, 1.9941288733412177, 0, 79, 11);
INSERT INTO prestiti VALUES(0, '2022-04-28', 111, 11153.178605190767, 5.6079918804402915, 0, 72, 7);
INSERT INTO prestiti VALUES(0, '2022-03-16', 26, 34596.6412743364, 9.9025618893459, 40, 13, 15);
INSERT INTO prestiti VALUES(0, '2022-03-15', 173, 32473.235898586918, 7.293648189352985, 0, 14, 4);
INSERT INTO prestiti VALUES(0, '2022-03-22', 111, 12874.225757525599, 4.951545607472239, 0, 4, 15);
INSERT INTO prestiti VALUES(0, '2022-03-27', 153, 33996.43429988231, 6.027437096762979, 11, 18, 8);
INSERT INTO prestiti VALUES(0, '2022-01-17', 159, 2062.6929711856933, 8.869166790803629, 38, 43, 17);
INSERT INTO prestiti VALUES(0, '2022-01-11', 28, 43756.951997098935, 5.486107139546436, 22, 8, 14);
INSERT INTO prestiti VALUES(0, '2022-03-23', 70, 27342.91534351734, 9.964714652493205, 0, 15, 3);
INSERT INTO prestiti VALUES(0, '2022-01-07', 149, 13690.540785854459, 8.289697644149642, 25, 70, 18);
INSERT INTO prestiti VALUES(0, '2022-03-11', 53, 34740.31068841217, 9.949291006709979, 24, 26, 20);
INSERT INTO prestiti VALUES(0, '2022-04-25', 51, 897.7662179614202, 9.086271544923465, 11, 13, 16);
INSERT INTO prestiti VALUES(0, '2022-03-24', 32, 20033.44500044612, 3.391624283645638, 0, 64, 15);
INSERT INTO prestiti VALUES(0, '2022-02-06', 163, 11917.048224874676, 2.92945352832935, 0, 78, 9);
INSERT INTO prestiti VALUES(0, '2022-04-15', 70, 39656.723570455404, 3.3193969673256856, 0, 52, 9);
INSERT INTO prestiti VALUES(0, '2022-03-24', 111, 40981.98823050299, 2.177109564227102, 0, 42, 2);
INSERT INTO prestiti VALUES(0, '2022-01-17', 46, 32087.62448011751, 8.353647481280252, 0, 37, 12);
INSERT INTO prestiti VALUES(0, '2022-01-05', 146, 39149.41746791709, 6.298083223185793, 0, 7, 19);
INSERT INTO prestiti VALUES(0, '2022-03-05', 180, 34644.20511498557, 3.083550526025244, 0, 28, 4);
INSERT INTO prestiti VALUES(0, '2022-04-16', 106, 436.4978581123761, 5.175015767821472, 0, 64, 3);
INSERT INTO prestiti VALUES(0, '2022-03-28', 55, 36795.64973045203, 4.293327174453738, 14, 33, 19);
INSERT INTO prestiti VALUES(0, '2022-02-28', 11, 33725.329924379024, 9.047388030812156, 0, 40, 9);
INSERT INTO prestiti VALUES(0, '2022-03-20', 123, 22705.512004982043, 4.966083988541337, 15, 17, 6);
INSERT INTO prestiti VALUES(0, '2022-03-16', 179, 31041.872526147803, 4.115674321844234, 30, 31, 4);
INSERT INTO prestiti VALUES(0, '2022-01-04', 156, 38019.65363449666, 5.241926908221845, 0, 9, 1);
INSERT INTO prestiti VALUES(0, '2022-01-10', 177, 29410.391336784152, 6.566977832134659, 33, 5, 12);
INSERT INTO prestiti VALUES(0, '2022-02-08', 52, 16810.498789756428, 2.7368911842740387, 0, 36, 14);
INSERT INTO prestiti VALUES(0, '2022-04-15', 128, 32278.947964668798, 2.3219224387368445, 0, 24, 7);
INSERT INTO prestiti VALUES(0, '2022-04-04', 77, 37747.30072586488, 1.7721261985746608, 28, 53, 9);
INSERT INTO prestiti VALUES(0, '2022-04-25', 140, 37969.11573841335, 5.5217416912990425, 26, 67, 11);
INSERT INTO prestiti VALUES(0, '2022-02-28', 93, 30805.730653963175, 2.065611785117945, 0, 79, 19);
INSERT INTO prestiti VALUES(0, '2022-02-19', 84, 48909.243785742256, 9.791021576617391, 12, 20, 1);
INSERT INTO prestiti VALUES(0, '2022-04-04', 173, 48775.535206520406, 8.857922097362383, 0, 35, 5);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di libri proveniente dal continente africano del 9 secolo.', 'Libri', 2898.91, 4.77, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di musica proveniente dal continente americano del 20 secolo.', 'Musica', NULL, 3.96, 7, 88, 0);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di armi proveniente dal continente antartico del 2 secolo.', 'Armi', NULL, 6.3, 2, 93, 0);
INSERT INTO beni VALUES(0, 'Un bel modello di libri proveniente dal continente americano del 5 secolo.', 'Libri', NULL, 5.94, 7, 17, 0);
INSERT INTO beni VALUES(0, 'Un gran esempio di pietre preziose proveniente dal continente antartico del 14 secolo.', 'Pietre preziose', 4124.32, 5.46, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di orologi proveniente dal continente asiatico del 11 secolo.', 'Orologi', 12715.01, 4.03, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di monete proveniente dal continente asiatico del 19 secolo.', 'Monete', NULL, 
3.8, 1, 41, 0);
INSERT INTO beni VALUES(0, 'Un gran esempio di elettronica proveniente dal continente africano del 14 secolo.', 'Elettronica', 
9858.05, 5.87, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di motori proveniente dal continente antartico del 12 secolo.', 'Motori', 27431.72, 
5.3, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di musica proveniente dal continente asiatico del 17 secolo.', 'Musica', 17411.16, 4.96, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di vestiti proveniente dal continente antartico del 10 secolo.', 'Vestiti', 41244.43, 1.46, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un unico modello di collane proveniente dal continente asiatico del 13 secolo.', 'Collane', 48002.45, 5.29, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di libri proveniente dal continente europeo del 1 secolo.', 'Libri', NULL, 9.78, 9, 18, 0);
INSERT INTO beni VALUES(0, 'Un emblema di armi proveniente dal continente europeo del 4 secolo.', 'Armi', NULL, 6.93, 5, 30, 0);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di oro proveniente dal continente africano del 16 secolo.', 'Oro', NULL, 7.03, 10, 15, 0);
INSERT INTO beni VALUES(0, 'Un gran esempio di memorabilia proveniente dal continente africano del 4 secolo.', 'Memorabilia', 36536.53, 6.3, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di pietre preziose proveniente dal continente europeo del 21 secolo.', 'Pietre 
preziose', 12645.6, 6.4, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di oro proveniente dal continente antartico del 6 secolo.', 'Oro', 47052.82, 
3.04, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di gioielli proveniente dal continente asiatico del 21 secolo.', 'Gioielli', 38509.66, 3.54, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un unico modello di oro proveniente dal continente asiatico del 12 secolo.', 'Oro', 3790.67, 2.98, 
NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di oro proveniente dal continente europeo del 1 secolo.', 'Oro', 5887.65, 5.0, 
NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un emblema di gioielli proveniente dal continente americano del 15 secolo.', 'Gioielli', 26022.69, 
5.78, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di arte proveniente dal continente europeo del 14 secolo.', 'Arte', 24986.01, 8.96, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di quadri proveniente dal continente africano del 20 secolo.', 'Quadri', 2249.05, 8.98, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di elettronica proveniente dal continente asiatico del 21 secolo.', 'Elettronica', 
21757.92, 9.98, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un unico modello di oro proveniente dal continente africano del 5 secolo.', 'Oro', NULL, 4.31, 8, 74, 0);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di collane proveniente dal continente africano del 15 secolo.', 'Collane', 13888.18, 2.23, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di arte proveniente dal continente americano del 7 secolo.', 'Arte', NULL, 3.42, 5, 
82, 0);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di oro proveniente dal continente africano del 5 secolo.', 'Oro', 10657.93, 6.62, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di armi proveniente dal continente antartico del 1 secolo.', 'Armi', 43938.33, 5.75, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di gioielli proveniente dal continente oceanico del 1 secolo.', 'Gioielli', NULL, 8.13, 3, 5, 0);
INSERT INTO beni VALUES(0, 'Un eccelso campione di arte proveniente dal continente oceanico del 21 secolo.', 'Arte', 4510.21, 4.73, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di libri proveniente dal continente europeo del 3 secolo.', 'Libri', 5463.13, 0.2, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di oro proveniente dal continente americano del 12 secolo.', 'Oro', NULL, 6.17, 8, 23, 0);
INSERT INTO beni VALUES(0, 'Un eccelso campione di collane proveniente dal continente asiatico del 3 secolo.', 'Collane', 17686.34, 4.08, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di armi proveniente dal continente antartico del 15 secolo.', 'Armi', 25163.75, 1.85, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un emblema di monete proveniente dal continente asiatico del 13 secolo.', 'Monete', NULL, 0.69, 5, 
43, 0);
INSERT INTO beni VALUES(0, 'Un bel modello di vestiti proveniente dal continente europeo del 19 secolo.', 'Vestiti', 43759.14, 
6.71, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di orologi proveniente dal continente americano del 21 secolo.', 'Orologi', 22345.68, 4.39, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di orologi proveniente dal continente asiatico del 20 secolo.', 'Orologi', NULL, 6.9, 7, 42, 0);
INSERT INTO beni VALUES(0, 'Un eccelso campione di videogiochi proveniente dal continente antartico del 8 secolo.', 'Videogiochi', NULL, 9.54, 7, 96, 0);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di monete proveniente dal continente asiatico del 16 secolo.', 'Monete', NULL, 4.17, 6, 79, 0);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di monete proveniente dal continente africano del 17 secolo.', 'Monete', NULL, 6.24, 10, 94, 0);
INSERT INTO beni VALUES(0, 'Un bel modello di pietre preziose proveniente dal continente americano del 20 secolo.', 'Pietre preziose', NULL, 3.32, 4, 72, 0);
INSERT INTO beni VALUES(0, 'Un eccelso campione di libri proveniente dal continente americano del 19 secolo.', 'Libri', 41698.61, 1.54, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un unico modello di musica proveniente dal continente oceanico del 7 secolo.', 'Musica', 15672.67, 
5.88, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di collane proveniente dal continente americano del 13 secolo.', 'Collane', 14581.21, 6.38, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di monete proveniente dal continente oceanico del 21 secolo.', 'Monete', NULL, 8.28, 8, 69, 0);
INSERT INTO beni VALUES(0, 'Un emblema di pietre preziose proveniente dal continente oceanico del 18 secolo.', 'Pietre preziose', NULL, 4.95, 8, 66, 0);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di monete proveniente dal continente europeo del 2 secolo.', 'Monete', NULL, 9.04, 9, 67, 0);
INSERT INTO beni VALUES(0, 'Un bel modello di orologi proveniente dal continente africano del 9 secolo.', 'Orologi', 30044.5, 6.42, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di videogiochi proveniente dal continente europeo del 19 secolo.', 'Videogiochi', 14563.54, 3.78, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di pietre preziose proveniente dal continente oceanico del 19 secolo.', 'Pietre preziose', 21112.97, 2.29, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di orologi proveniente dal continente oceanico del 13 secolo.', 'Orologi', 19236.89, 4.29, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di quadri proveniente dal continente americano del 14 secolo.', 'Quadri', NULL, 4.41, 9, 64, 0);
INSERT INTO beni VALUES(0, 'Un unico modello di collane proveniente dal continente africano del 12 secolo.', 'Collane', 13049.25, 9.16, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di gioielli proveniente dal continente antartico del 9 secolo.', 'Gioielli', 12213.96, 1.67, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di libri proveniente dal continente europeo del 11 secolo.', 'Libri', NULL, 2.23, 1, 44, 0);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di musica proveniente dal continente americano del 16 secolo.', 'Musica', 18739.73, 3.4, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di videogiochi proveniente dal continente americano del 7 secolo.', 'Videogiochi', 27352.12, 1.0, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di musica proveniente dal continente europeo del 18 secolo.', 'Musica', 16288.77, 0.27, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un unico modello di vestiti proveniente dal continente europeo del 3 secolo.', 'Vestiti', 31893.7, 
0.3, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un emblema di quadri proveniente dal continente americano del 6 secolo.', 'Quadri', 18910.43, 3.45, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di libri proveniente dal continente antartico del 8 secolo.', 'Libri', 40152.46, 3.46, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di monete proveniente dal continente oceanico del 20 secolo.', 'Monete', 20145.93, 4.71, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di libri proveniente dal continente europeo del 2 secolo.', 'Libri', 48052.08, 
2.74, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di orologi proveniente dal continente americano del 13 secolo.', 'Orologi', 5710.59, 5.69, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di orologi proveniente dal continente asiatico del 1 secolo.', 'Orologi', 14944.69, 5.77, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di vestiti proveniente dal continente europeo del 16 secolo.', 'Vestiti', 13050.43, 7.73, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di vestiti proveniente dal continente americano del 21 secolo.', 'Vestiti', NULL, 0.2, 2, 68, 0);
INSERT INTO beni VALUES(0, 'Un eccelso campione di oro proveniente dal continente oceanico del 20 secolo.', 'Oro', NULL, 4.1, 8, 12, 0);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di oro proveniente dal continente oceanico del 14 secolo.', 'Oro', 17122.11, 1.97, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di collane proveniente dal continente europeo del 4 secolo.', 'Collane', 45824.94, 2.72, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di videogiochi proveniente dal continente antartico del 18 secolo.', 'Videogiochi', 28371.46, 6.15, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di oro proveniente dal continente americano del 17 secolo.', 'Oro', 4071.46, 
1.09, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di armi proveniente dal continente europeo del 4 secolo.', 'Armi', 32374.93, 8.0, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di armi proveniente dal continente africano del 13 secolo.', 'Armi', 44841.28, 2.77, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di arte proveniente dal continente asiatico del 11 secolo.', 'Arte', NULL, 8.6, 9, 
36, 0);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di gioielli proveniente dal continente africano del 6 secolo.', 'Gioielli', NULL, 
9.75, 6, 91, 0);
INSERT INTO beni VALUES(0, 'Un emblema di motori proveniente dal continente oceanico del 12 secolo.', 'Motori', NULL, 5.12, 1, 
19, 0);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di oro proveniente dal continente africano del 1 secolo.', 'Oro', NULL, 6.36, 2, 2, 0);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di orologi proveniente dal continente europeo del 2 secolo.', 'Orologi', NULL, 0.65, 9, 87, 0);
INSERT INTO beni VALUES(0, 'Un gran esempio di memorabilia proveniente dal continente oceanico del 8 secolo.', 'Memorabilia', NULL, 7.74, 8, 35, 0);
INSERT INTO beni VALUES(0, 'Un eccelso campione di argento proveniente dal continente africano del 16 secolo.', 'Argento', 496.42, 4.78, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di monete proveniente dal continente antartico del 5 secolo.', 'Monete', 26335.81, 2.43, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di orologi proveniente dal continente americano del 17 secolo.', 'Orologi', 3066.44, 9.72, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di musica proveniente dal continente americano del 5 secolo.', 'Musica', 36718.87, 4.63, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un emblema di vestiti proveniente dal continente asiatico del 5 secolo.', 'Vestiti', NULL, 3.4, 7, 
21, 0);
INSERT INTO beni VALUES(0, 'Un gran esempio di gioielli proveniente dal continente antartico del 19 secolo.', 'Gioielli', 25401.9, 0.22, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di quadri proveniente dal continente europeo del 7 secolo.', 'Quadri', 38386.8, 9.0, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di videogiochi proveniente dal continente antartico del 5 secolo.', 'Videogiochi', 37752.79, 7.44, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di monete proveniente dal continente europeo del 2 secolo.', 'Monete', 33240.87, 4.14, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di collane proveniente dal continente oceanico del 15 secolo.', 'Collane', 24080.31, 0.59, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di arte proveniente dal continente africano del 11 secolo.', 'Arte', 33000.1, 8.24, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di collane proveniente dal continente asiatico del 17 secolo.', 'Collane', NULL, 2.69, 7, 47, 0);
INSERT INTO beni VALUES(0, 'Un emblema di pietre preziose proveniente dal continente antartico del 1 secolo.', 'Pietre preziose', 1826.2, 5.3, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di libri proveniente dal continente europeo del 11 secolo.', 'Libri', NULL, 4.64, 6, 45, 0);
INSERT INTO beni VALUES(0, 'Un gran esempio di orologi proveniente dal continente asiatico del 5 secolo.', 'Orologi', 17334.81, 3.98, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di orologi proveniente dal continente americano del 11 secolo.', 'Orologi', 14620.82, 8.21, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di gioielli proveniente dal continente americano del 15 secolo.', 'Gioielli', 21790.12, 2.87, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di argento proveniente dal continente americano del 19 secolo.', 'Argento', NULL, 6.82, 3, 98, 0);
INSERT INTO beni VALUES(0, 'Un bel modello di arte proveniente dal continente africano del 13 secolo.', 'Arte', 37991.11, 5.24, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di pietre preziose proveniente dal continente africano del 6 secolo.', 'Pietre preziose', 7351.68, 3.57, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di armi proveniente dal continente asiatico del 4 secolo.', 'Armi', 7025.78, 4.82, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di gioielli proveniente dal continente oceanico del 9 secolo.', 'Gioielli', 11766.5, 4.25, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di orologi proveniente dal continente asiatico del 5 secolo.', 'Orologi', 16674.64, 7.75, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di orologi proveniente dal continente antartico del 11 secolo.', 'Orologi', 49983.47, 4.45, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di orologi proveniente dal continente antartico del 11 secolo.', 'Orologi', NULL, 9.22, 3, 55, 0);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di musica proveniente dal continente antartico del 6 secolo.', 'Musica', NULL, 4.39, 2, 73, 0);
INSERT INTO beni VALUES(0, 'Un unico modello di collane proveniente dal continente americano del 19 secolo.', 'Collane', NULL, 
2.8, 7, 46, 0);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di orologi proveniente dal continente oceanico del 12 secolo.', 'Orologi', NULL, 6.3, 6, 62, 0);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di memorabilia proveniente dal continente asiatico del 8 secolo.', 'Memorabilia', 8206.87, 5.25, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di gioielli proveniente dal continente americano del 19 secolo.', 'Gioielli', 26633.69, 7.74, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di argento proveniente dal continente antartico del 12 secolo.', 'Argento', 40472.53, 1.56, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di elettronica proveniente dal continente antartico del 13 secolo.', 'Elettronica', 16707.99, 8.81, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di elettronica proveniente dal continente americano del 16 secolo.', 'Elettronica', 45223.88, 3.53, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un unico modello di musica proveniente dal continente asiatico del 19 secolo.', 'Musica', NULL, 2.54, 8, 63, 0);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di musica proveniente dal continente antartico del 4 secolo.', 'Musica', 6105.12, 8.78, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di gioielli proveniente dal continente oceanico del 15 secolo.', 'Gioielli', 
NULL, 6.68, 9, 89, 0);
INSERT INTO beni VALUES(0, 'Un bel modello di memorabilia proveniente dal continente oceanico del 18 secolo.', 'Memorabilia', NULL, 9.71, 4, 86, 0);
INSERT INTO beni VALUES(0, 'Un bel modello di videogiochi proveniente dal continente europeo del 7 secolo.', 'Videogiochi', 151.15, 8.73, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di oro proveniente dal continente africano del 13 secolo.', 'Oro', NULL, 1.82, 3, 24, 0);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di arte proveniente dal continente europeo del 9 secolo.', 'Arte', NULL, 1.74, 9, 
20, 0);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di arte proveniente dal continente africano del 15 secolo.', 'Arte', NULL, 1.51, 8, 75, 0);
INSERT INTO beni VALUES(0, 'Un unico modello di pietre preziose proveniente dal continente antartico del 1 secolo.', 'Pietre preziose', 26621.22, 7.09, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di vestiti proveniente dal continente antartico del 2 secolo.', 'Vestiti', 19008.5, 6.62, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di elettronica proveniente dal continente americano del 3 secolo.', 'Elettronica', 19809.05, 7.07, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di elettronica proveniente dal continente antartico del 1 secolo.', 'Elettronica', 41320.66, 3.48, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un emblema di quadri proveniente dal continente africano del 18 secolo.', 'Quadri', 8255.67, 3.59, 
NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un unico modello di pietre preziose proveniente dal continente oceanico del 3 secolo.', 'Pietre preziose', NULL, 4.81, 8, 85, 0);
INSERT INTO beni VALUES(0, 'Un gran esempio di oro proveniente dal continente africano del 17 secolo.', 'Oro', 11885.7, 3.75, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di oro proveniente dal continente americano del 6 secolo.', 'Oro', 31660.45, 3.32, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di memorabilia proveniente dal continente antartico del 12 secolo.', 'Memorabilia', 47432.46, 4.7, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di memorabilia proveniente dal continente europeo del 18 secolo.', 'Memorabilia', 22923.65, 2.93, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un unico modello di argento proveniente dal continente africano del 11 secolo.', 'Argento', NULL, 2.08, 4, 13, 0);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di quadri proveniente dal continente oceanico del 17 secolo.', 'Quadri', 41693.17, 0.55, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di arte proveniente dal continente oceanico del 4 secolo.', 'Arte', NULL, 7.48, 4, 
28, 0);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di monete proveniente dal continente oceanico del 15 secolo.', 'Monete', NULL, 3.38, 5, 95, 0);
INSERT INTO beni VALUES(0, 'Un emblema di argento proveniente dal continente oceanico del 17 secolo.', 'Argento', NULL, 3.42, 3, 78, 0);
INSERT INTO beni VALUES(0, 'Un unico modello di quadri proveniente dal continente oceanico del 10 secolo.', 'Quadri', NULL, 6.95, 3, 90, 0);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di vestiti proveniente dal continente africano del 9 secolo.', 'Vestiti', NULL, 7.01, 3, 11, 0);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di oro proveniente dal continente europeo del 11 secolo.', 'Oro', 20250.86, 0.56, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di gioielli proveniente dal continente oceanico del 12 secolo.', 'Gioielli', NULL, 6.24, 4, 77, 0);
INSERT INTO beni VALUES(0, 'Un unico modello di pietre preziose proveniente dal continente oceanico del 16 secolo.', 'Pietre preziose', 27891.45, 3.86, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di quadri proveniente dal continente africano del 8 secolo.', 'Quadri', 
NULL, 5.1, 6, 10, 0);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di argento proveniente dal continente africano del 11 secolo.', 'Argento', 12608.06, 0.93, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di musica proveniente dal continente africano del 6 secolo.', 'Musica', 25267.22, 1.42, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di libri proveniente dal continente europeo del 12 secolo.', 'Libri', 46311.73, 1.75, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di elettronica proveniente dal continente europeo del 10 secolo.', 'Elettronica', 23099.19, 1.92, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di quadri proveniente dal continente africano del 20 secolo.', 'Quadri', 29472.61, 0.96, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di collane proveniente dal continente oceanico del 11 secolo.', 'Collane', 44309.11, 0.92, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di quadri proveniente dal continente europeo del 14 secolo.', 'Quadri', 47498.14, 7.36, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di motori proveniente dal continente africano del 11 secolo.', 'Motori', 26297.76, 9.24, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un unico modello di libri proveniente dal continente europeo del 21 secolo.', 'Libri', NULL, 7.66, 
5, 8, 0);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di orologi proveniente dal continente asiatico del 11 secolo.', 'Orologi', 49030.04, 7.82, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di vestiti proveniente dal continente europeo del 8 secolo.', 'Vestiti', NULL, 6.19, 4, 84, 0);
INSERT INTO beni VALUES(0, 'Un gran esempio di monete proveniente dal continente africano del 17 secolo.', 'Monete', 14024.22, 
4.79, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di musica proveniente dal continente oceanico del 8 secolo.', 'Musica', 9336.61, 9.0, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di libri proveniente dal continente americano del 3 secolo.', 'Libri', NULL, 5.88, 3, 32, 0);
INSERT INTO beni VALUES(0, 'Un unico modello di arte proveniente dal continente antartico del 12 secolo.', 'Arte', NULL, 7.44, 
1, 40, 0);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di argento proveniente dal continente oceanico del 7 secolo.', 'Argento', 32441.85, 7.93, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di arte proveniente dal continente americano del 17 secolo.', 'Arte', NULL, 8.49, 2, 57, 0);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di armi proveniente dal continente asiatico del 16 secolo.', 'Armi', 10952.55, 8.36, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un emblema di monete proveniente dal continente oceanico del 16 secolo.', 'Monete', 37242.09, 2.67, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un emblema di videogiochi proveniente dal continente oceanico del 7 secolo.', 'Videogiochi', NULL, 
3.92, 7, 3, 0);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di videogiochi proveniente dal continente americano del 13 secolo.', 'Videogiochi', 24627.85, 5.6, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di musica proveniente dal continente africano del 1 secolo.', 'Musica', 43987.09, 4.48, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di collane proveniente dal continente asiatico del 10 secolo.', 'Collane', NULL, 4.86, 8, 25, 0);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di pietre preziose proveniente dal continente europeo del 3 secolo.', 'Pietre preziose', 32395.16, 8.12, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di vestiti proveniente dal continente americano del 14 secolo.', 'Vestiti', NULL, 1.45, 6, 38, 0);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di gioielli proveniente dal continente oceanico del 17 secolo.', 'Gioielli', 
3664.47, 3.75, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di quadri proveniente dal continente africano del 16 secolo.', 'Quadri', 1390.57, 7.14, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di argento proveniente dal continente americano del 6 secolo.', 'Argento', 16605.89, 6.15, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di videogiochi proveniente dal continente europeo del 1 secolo.', 'Videogiochi', 9361.85, 8.71, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un emblema di videogiochi proveniente dal continente europeo del 20 secolo.', 'Videogiochi', NULL, 
9.58, 7, 14, 0);
INSERT INTO beni VALUES(0, 'Un gran esempio di argento proveniente dal continente oceanico del 6 secolo.', 'Argento', NULL, 3.76, 10, 97, 0);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di quadri proveniente dal continente europeo del 5 secolo.', 'Quadri', NULL, 1.56, 3, 29, 0);
INSERT INTO beni VALUES(0, 'Un unico modello di oro proveniente dal continente oceanico del 10 secolo.', 'Oro', 10189.76, 2.89, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di orologi proveniente dal continente americano del 13 secolo.', 'Orologi', NULL, 4.04, 1, 31, 0);
INSERT INTO beni VALUES(0, 'Un unico modello di libri proveniente dal continente antartico del 13 secolo.', 'Libri', 30835.85, 
4.69, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di elettronica proveniente dal continente antartico del 9 secolo.', 'Elettronica', NULL, 4.32, 4, 26, 0);
INSERT INTO beni VALUES(0, 'Un unico modello di pietre preziose proveniente dal continente asiatico del 14 secolo.', 'Pietre preziose', 26354.67, 8.0, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di pietre preziose proveniente dal continente antartico del 9 secolo.', 'Pietre preziose', 7546.36, 9.79, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di pietre preziose proveniente dal continente antartico del 12 secolo.', 'Pietre preziose', 20976.0, 6.78, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di monete proveniente dal continente asiatico del 1 secolo.', 'Monete', 33506.8, 0.79, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di argento proveniente dal continente antartico del 15 secolo.', 'Argento', 44180.82, 8.33, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di monete proveniente dal continente europeo del 15 secolo.', 'Monete', 33309.06, 2.81, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di arte proveniente dal continente antartico del 8 secolo.', 'Arte', NULL, 7.98, 4, 7, 0);
INSERT INTO beni VALUES(0, 'Un bel modello di musica proveniente dal continente africano del 16 secolo.', 'Musica', NULL, 4.81, 3, 53, 0);
INSERT INTO beni VALUES(0, 'Un gran esempio di arte proveniente dal continente antartico del 9 secolo.', 'Arte', NULL, 0.58, 9, 4, 0);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di quadri proveniente dal continente antartico del 13 secolo.', 'Quadri', 25074.14, 4.47, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di argento proveniente dal continente americano del 3 secolo.', 'Argento', NULL, 7.6, 5, 83, 0);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di monete proveniente dal continente americano del 17 secolo.', 'Monete', NULL, 2.35, 5, 99, 0);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di motori proveniente dal continente africano del 18 secolo.', 'Motori', 4104.78, 2.24, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di memorabilia proveniente dal continente oceanico del 13 secolo.', 'Memorabilia', 41041.82, 9.08, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di monete proveniente dal continente asiatico del 2 secolo.', 'Monete', 
NULL, 4.51, 2, 6, 0);
INSERT INTO beni VALUES(0, 'Un bel modello di libri proveniente dal continente africano del 6 secolo.', 'Libri', 38569.78, 1.05, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di argento proveniente dal continente africano del 8 secolo.', 'Argento', 3321.96, 7.32, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di arte proveniente dal continente oceanico del 20 secolo.', 'Arte', 19113.82, 3.97, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di pietre preziose proveniente dal continente asiatico del 3 secolo.', 'Pietre preziose', 28449.25, 9.7, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di elettronica proveniente dal continente asiatico del 2 secolo.', 'Elettronica', NULL, 7.11, 10, 50, 0);
INSERT INTO beni VALUES(0, 'Un eccelso campione di oro proveniente dal continente africano del 19 secolo.', 'Oro', 29754.3, 2.47, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di monete proveniente dal continente oceanico del 14 secolo.', 'Monete', 13144.08, 0.15, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di libri proveniente dal continente antartico del 9 secolo.', 'Libri', 32412.75, 1.55, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di musica proveniente dal continente oceanico del 5 secolo.', 'Musica', 21706.95, 
4.2, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un unico modello di pietre preziose proveniente dal continente europeo del 18 secolo.', 'Pietre preziose', NULL, 7.88, 5, 22, 0);
INSERT INTO beni VALUES(0, 'Un gran esempio di motori proveniente dal continente europeo del 13 secolo.', 'Motori', 8089.86, 1.12, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di quadri proveniente dal continente europeo del 6 secolo.', 'Quadri', 39438.68, 1.01, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un unico modello di elettronica proveniente dal continente oceanico del 4 secolo.', 'Elettronica', 
13297.32, 8.08, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di arte proveniente dal continente americano del 12 secolo.', 'Arte', 38489.0, 8.81, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di quadri proveniente dal continente europeo del 5 secolo.', 'Quadri', NULL, 8.3, 1, 51, 0);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di videogiochi proveniente dal continente africano del 20 secolo.', 'Videogiochi', 46561.99, 4.72, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di elettronica proveniente dal continente africano del 9 secolo.', 'Elettronica', NULL, 2.68, 1, 61, 0);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di motori proveniente dal continente americano del 8 secolo.', 'Motori', NULL, 2.26, 5, 54, 0);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di videogiochi proveniente dal continente oceanico del 6 secolo.', 'Videogiochi', 8172.77, 8.7, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di arte proveniente dal continente africano del 21 secolo.', 'Arte', 24957.8, 3.4, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di memorabilia proveniente dal continente antartico del 8 secolo.', 'Memorabilia', NULL, 8.17, 9, 52, 0);
INSERT INTO beni VALUES(0, 'Un unico modello di orologi proveniente dal continente europeo del 8 secolo.', 'Orologi', NULL, 8.13, 10, 27, 0);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di collane proveniente dal continente asiatico del 11 secolo.', 'Collane', 2814.46, 8.91, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un unico modello di libri proveniente dal continente africano del 9 secolo.', 'Libri', NULL, 2.8, 3, 39, 0);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di argento proveniente dal continente europeo del 5 secolo.', 'Argento', 34419.99, 0.66, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di quadri proveniente dal continente africano del 10 secolo.', 'Quadri', 33808.49, 1.4, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un unico modello di motori proveniente dal continente oceanico del 6 secolo.', 'Motori', 26288.11, 
6.3, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di argento proveniente dal continente europeo del 12 secolo.', 'Argento', 16679.21, 6.97, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di elettronica proveniente dal continente americano del 16 secolo.', 'Elettronica', NULL, 2.18, 6, 1, 0);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di oro proveniente dal continente europeo del 7 secolo.', 'Oro', 49171.47, 5.79, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di videogiochi proveniente dal continente oceanico del 1 secolo.', 'Videogiochi', 40737.89, 9.06, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di vestiti proveniente dal continente americano del 18 secolo.', 'Vestiti', NULL, 3.93, 2, 16, 0);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di vestiti proveniente dal continente europeo del 10 secolo.', 'Vestiti', NULL, 6.43, 6, 80, 0);
INSERT INTO beni VALUES(0, 'Un emblema di vestiti proveniente dal continente europeo del 3 secolo.', 'Vestiti', 42694.81, 3.81, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di motori proveniente dal continente oceanico del 20 secolo.', 'Motori', NULL, 7.31, 5, 9, 0);
INSERT INTO beni VALUES(0, 'Un emblema di quadri proveniente dal continente oceanico del 19 secolo.', 'Quadri', NULL, 5.4, 2, 59, 0);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di motori proveniente dal continente oceanico del 5 secolo.', 'Motori', 42065.0, 4.14, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di motori proveniente dal continente europeo del 2 secolo.', 'Motori', 1466.52, 7.02, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più costosi esemplari di collane proveniente dal continente europeo del 18 secolo.', 'Collane', 32229.57, 8.29, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di gioielli proveniente dal continente africano del 17 secolo.', 'Gioielli', 5650.04, 7.63, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un emblema di quadri proveniente dal continente asiatico del 14 secolo.', 'Quadri', NULL, 4.27, 6, 
33, 0);
INSERT INTO beni VALUES(0, 'Un bel modello di oro proveniente dal continente antartico del 8 secolo.', 'Oro', 25081.83, 5.63, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di argento proveniente dal continente oceanico del 3 secolo.', 'Argento', 15871.85, 8.45, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di vestiti proveniente dal continente europeo del 20 secolo.', 'Vestiti', NULL, 4.17, 6, 92, 0);
INSERT INTO beni VALUES(0, 'Un bel modello di argento proveniente dal continente americano del 9 secolo.', 'Argento', 16301.43, 8.61, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di monete proveniente dal continente europeo del 2 secolo.', 'Monete', NULL, 0.6, 3, 48, 0);
INSERT INTO beni VALUES(0, 'Un eccelso campione di elettronica proveniente dal continente africano del 14 secolo.', 'Elettronica', NULL, 7.85, 2, 65, 0);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di musica proveniente dal continente asiatico del 17 secolo.', 'Musica', 43729.94, 0.69, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di armi proveniente dal continente europeo del 15 secolo.', 'Armi', 44916.35, 3.77, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di elettronica proveniente dal continente africano del 8 secolo.', 'Elettronica', NULL, 8.25, 3, 58, 0);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di motori proveniente dal continente americano del 3 secolo.', 'Motori', 29877.25, 0.61, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di motori proveniente dal continente antartico del 18 secolo.', 'Motori', 31564.37, 6.3, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un emblema di collane proveniente dal continente africano del 9 secolo.', 'Collane', 38322.11, 8.21, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un unico modello di vestiti proveniente dal continente europeo del 5 secolo.', 'Vestiti', 29270.44, 9.46, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di armi proveniente dal continente africano del 17 secolo.', 'Armi', 39823.17, 8.97, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di quadri proveniente dal continente antartico del 2 secolo.', 'Quadri', 2320.28, 6.03, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di pietre preziose proveniente dal continente americano del 15 secolo.', 'Pietre preziose', 31667.79, 1.39, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di memorabilia proveniente dal continente oceanico del 11 secolo.', 'Memorabilia', 26601.11, 0.68, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di orologi proveniente dal continente americano del 6 secolo.', 'Orologi', 30415.38, 2.0, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di musica proveniente dal continente antartico del 6 secolo.', 'Musica', NULL, 3.03, 8, 81, 0);
INSERT INTO beni VALUES(0, 'Un unico modello di monete proveniente dal continente africano del 9 secolo.', 'Monete', 34886.09, 
6.67, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di collane proveniente dal continente africano del 21 secolo.', 'Collane', NULL, 3.55, 7, 37, 0);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di gioielli proveniente dal continente oceanico del 6 secolo.', 'Gioielli', 48178.32, 1.37, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di armi proveniente dal continente antartico del 5 secolo.', 'Armi', 21922.95, 3.4, 
NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un emblema di libri proveniente dal continente europeo del 16 secolo.', 'Libri', 1007.85, 9.84, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di collane proveniente dal continente europeo del 12 secolo.', 'Collane', NULL, 1.69, 10, 71, 0);
INSERT INTO beni VALUES(0, 'Un gran esempio di monete proveniente dal continente americano del 18 secolo.', 'Monete', 1277.45, 
2.31, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un unico modello di memorabilia proveniente dal continente oceanico del 14 secolo.', 'Memorabilia', 14085.14, 2.36, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di quadri proveniente dal continente asiatico del 17 secolo.', 'Quadri', NULL, 0.81, 4, 76, 0);
INSERT INTO beni VALUES(0, 'Un bel modello di libri proveniente dal continente europeo del 5 secolo.', 'Libri', 11576.51, 4.45, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di collane proveniente dal continente antartico del 11 secolo.', 'Collane', 41827.33, 9.79, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un emblema di arte proveniente dal continente oceanico del 10 secolo.', 'Arte', NULL, 6.62, 9, 70, 
0);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di elettronica proveniente dal continente oceanico del 1 secolo.', 'Elettronica', 
NULL, 4.32, 5, 60, 0);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di libri proveniente dal continente asiatico del 15 secolo.', 'Libri', 36903.08, 5.48, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di armi proveniente dal continente europeo del 21 secolo.', 'Armi', 27780.29, 9.89, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di vestiti proveniente dal continente europeo del 20 secolo.', 'Vestiti', 11050.21, 7.66, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di quadri proveniente dal continente europeo del 4 secolo.', 'Quadri', NULL, 
4.28, 1, 100, 0);
INSERT INTO beni VALUES(0, 'Un eccelso campione di orologi proveniente dal continente asiatico del 6 secolo.', 'Orologi', NULL, 0.42, 6, 49, 0);
INSERT INTO beni VALUES(0, 'Un unico modello di memorabilia proveniente dal continente americano del 19 secolo.', 'Memorabilia', 22475.86, 1.89, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un unico modello di musica proveniente dal continente antartico del 17 secolo.', 'Musica', 47676.84, 7.04, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di quadri proveniente dal continente asiatico del 12 secolo.', 'Quadri', NULL, 8.49, 10, 56, 0);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di armi proveniente dal continente oceanico del 14 secolo.', 'Armi', 36577.81, 4.24, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di arte proveniente dal continente oceanico del 19 secolo.', 'Arte', 35364.66, 7.87, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di elettronica proveniente dal continente antartico del 5 secolo.', 'Elettronica', 48820.43, 9.04, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di videogiochi proveniente dal continente europeo del 20 secolo.', 'Videogiochi', 
7328.27, 7.67, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di motori proveniente dal continente asiatico del 19 secolo.', 'Motori', 42860.92, 
2.92, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di gioielli proveniente dal continente africano del 3 secolo.', 'Gioielli', NULL, 
2.73, 5, 34, 0);
INSERT INTO beni VALUES(0, 'Un bel modello di orologi proveniente dal continente asiatico del 17 secolo.', 'Orologi', 25441.14, 0.99, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di motori proveniente dal continente oceanico del 1 secolo.', 'Motori', NULL, 2.74, 
4, 69, 0);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di monete proveniente dal continente asiatico del 8 secolo.', 'Monete', 15491.69, 
8.99, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un sublime pezzo di oro proveniente dal continente asiatico del 19 secolo.', 'Oro', 7007.56, 5.68, 
NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un significativo esemplare di oro proveniente dal continente antartico del 10 secolo.', 'Oro', 46618.54, 9.29, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di argento proveniente dal continente europeo del 8 secolo.', 'Argento', 19244.4, 9.85, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di armi proveniente dal continente oceanico del 17 secolo.', 'Armi', 45411.62, 1.03, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un eccelso campione di monete proveniente dal continente europeo del 8 secolo.', 'Monete', 27377.65, 4.63, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di orologi proveniente dal continente europeo del 7 secolo.', 'Orologi', 33777.0, 4.95, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un bel modello di monete proveniente dal continente europeo del 18 secolo.', 'Monete', 29782.18, 8.75, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un gran esempio di elettronica proveniente dal continente americano del 19 secolo.', 'Elettronica', 36984.44, 7.96, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un unico modello di oro proveniente dal continente europeo del 3 secolo.', 'Oro', NULL, 3.68, 2, 67, 0);
INSERT INTO beni VALUES(0, 'Un emblema di libri proveniente dal continente americano del 9 secolo.', 'Libri', 16170.78, 3.53, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Tra i più rari pezzi di monete proveniente dal continente europeo del 2 secolo.', 'Monete', NULL, 0.86, 2, 19, 0);
INSERT INTO beni VALUES(0, 'Un unico modello di videogiochi proveniente dal continente asiatico del 2 secolo.', 'Videogiochi', 
7545.37, 9.32, NULL, NULL, 1);
INSERT INTO beni VALUES(0, 'Un ottimo particolare di argento proveniente dal continente oceanico del 13 secolo.', 'Argento', NULL, 4.34, 10, 41, 0);
INSERT INTO beni VALUES(0, 'Un eccelso campione di argento proveniente dal continente oceanico del 21 secolo.', 'Argento', 34416.88, 6.36, NULL, NULL, 1);
INSERT INTO valutazioni VALUES('+39 26456139', 153, '2022-02-13', 2555.57);
INSERT INTO valutazioni VALUES('+39 58564300', 105, '2022-01-14', 3643.36);
INSERT INTO valutazioni VALUES('+39 78854097', 123, '2022-02-02', 2209.15);
INSERT INTO valutazioni VALUES('+39 39673579', 57, '2022-04-19', 6402.91);
INSERT INTO valutazioni VALUES('+39 21488689', 221, '2022-02-09', 5519.25);
INSERT INTO valutazioni VALUES('+39 40972876', 251, '2022-04-11', 5347.84);
INSERT INTO valutazioni VALUES('+39 63395873', 282, '2022-02-11', 2117.03);
INSERT INTO valutazioni VALUES('+39 78854097', 74, '2022-04-01', 2414.74);
INSERT INTO valutazioni VALUES('+39 63395873', 199, '2022-03-10', 9875.25);
INSERT INTO valutazioni VALUES('+39 18411751', 274, '2022-01-29', 7881.61);
INSERT INTO valutazioni VALUES('+39 95720384', 109, '2022-01-27', 3080.82);
INSERT INTO valutazioni VALUES('+39 59618616', 17, '2022-01-30', 6383.77);
INSERT INTO valutazioni VALUES('+39 23403421', 236, '2022-04-23', 5315.57);
INSERT INTO valutazioni VALUES('+39 62430483', 260, '2022-03-28', 5691.16);
INSERT INTO valutazioni VALUES('+39 63395873', 59, '2022-02-02', 4178.78);
INSERT INTO valutazioni VALUES('+39 27933974', 283, '2022-01-02', 4783.56);
INSERT INTO valutazioni VALUES('+39 78518951', 300, '2022-03-27', 4071.63);
INSERT INTO valutazioni VALUES('+39 77239121', 64, '2022-01-31', 7691.7);
INSERT INTO valutazioni VALUES('+39 18411751', 19, '2022-03-25', 1041.09);
INSERT INTO valutazioni VALUES('+39 59618616', 87, '2022-03-21', 880.84);
INSERT INTO valutazioni VALUES('+39 22446160', 221, '2022-01-03', 7308.76);
INSERT INTO valutazioni VALUES('+39 33371966', 88, '2022-01-27', 4524.38);
INSERT INTO valutazioni VALUES('+39 33371966', 120, '2022-04-30', 5625.8);
INSERT INTO valutazioni VALUES('+39 95720384', 176, '2022-01-22', 6148.66);
INSERT INTO valutazioni VALUES('+39 63395873', 118, '2022-03-24', 974.36);
INSERT INTO valutazioni VALUES('+39 18411751', 288, '2022-01-06', 2877.5);
INSERT INTO valutazioni VALUES('+39 62430483', 93, '2022-01-26', 1933.08);
INSERT INTO valutazioni VALUES('+39 62430483', 287, '2022-04-08', 7799.84);
INSERT INTO valutazioni VALUES('+39 58564300', 258, '2022-02-02', 885.56);
INSERT INTO valutazioni VALUES('+39 62790173', 95, '2022-02-19', 5847.09);
INSERT INTO valutazioni VALUES('+39 24698683', 289, '2022-04-11', 1753.03);
INSERT INTO valutazioni VALUES('+39 99820747', 283, '2022-02-20', 9444.9);
INSERT INTO valutazioni VALUES('+39 83181743', 134, '2022-02-17', 717.97);
INSERT INTO valutazioni VALUES('+39 28857172', 169, '2022-01-25', 2227.32);
INSERT INTO valutazioni VALUES('+39 63395873', 127, '2022-02-03', 2437.64);
INSERT INTO valutazioni VALUES('+39 77239121', 202, '2022-04-02', 3689.63);
INSERT INTO valutazioni VALUES('+39 18350889', 77, '2022-01-04', 157.48);
INSERT INTO valutazioni VALUES('+39 31571812', 87, '2022-01-02', 171.65);
INSERT INTO valutazioni VALUES('+39 24698683', 251, '2022-01-02', 9911.46);
INSERT INTO valutazioni VALUES('+39 60693279', 171, '2022-03-02', 6323.61);
INSERT INTO valutazioni VALUES('+39 82225663', 12, '2022-02-05', 586.94);
INSERT INTO valutazioni VALUES('+39 03674575', 174, '2022-04-29', 5039.88);
INSERT INTO valutazioni VALUES('+39 73122373', 176, '2022-03-09', 5742.42);
INSERT INTO valutazioni VALUES('+39 82225663', 111, '2022-02-27', 7299.97);
INSERT INTO valutazioni VALUES('+39 58564300', 219, '2022-01-22', 5954.97);
INSERT INTO valutazioni VALUES('+39 52700958', 1, '2022-02-11', 6524.53);
INSERT INTO valutazioni VALUES('+39 77367952', 4, '2022-01-30', 6096.97);
INSERT INTO valutazioni VALUES('+39 13431019', 275, '2022-02-09', 4438.33);
INSERT INTO valutazioni VALUES('+39 11565362', 27, '2022-01-18', 9907.43);
INSERT INTO valutazioni VALUES('+39 71980864', 38, '2022-03-18', 1058.37);
INSERT INTO valutazioni VALUES('+39 61489701', 56, '2022-04-30', 2037.96);
INSERT INTO valutazioni VALUES('+39 58564300', 23, '2022-04-26', 3943.36);
INSERT INTO valutazioni VALUES('+39 23754873', 64, '2022-01-28', 9048.08);
INSERT INTO valutazioni VALUES('+39 76581278', 69, '2022-02-26', 7952.73);
INSERT INTO valutazioni VALUES('+39 58564300', 39, '2022-01-17', 7101.23);
INSERT INTO valutazioni VALUES('+39 78039697', 99, '2022-02-28', 4962.06);
INSERT INTO valutazioni VALUES('+39 23754873', 54, '2022-03-30', 8676.59);
INSERT INTO valutazioni VALUES('+39 28857172', 208, '2022-04-18', 2990.78);
INSERT INTO valutazioni VALUES('+39 39878581', 68, '2022-04-21', 3903.21);
INSERT INTO valutazioni VALUES('+39 24698683', 212, '2022-04-08', 8946.38);
INSERT INTO valutazioni VALUES('+39 71980864', 68, '2022-04-28', 5525.98);
INSERT INTO valutazioni VALUES('+39 04191883', 90, '2022-04-25', 202.29);
INSERT INTO valutazioni VALUES('+39 35524650', 276, '2022-01-16', 1967.74);
INSERT INTO valutazioni VALUES('+39 28857172', 239, '2022-03-28', 4382.81);
INSERT INTO valutazioni VALUES('+39 21488689', 160, '2022-01-20', 2448.44);
INSERT INTO valutazioni VALUES('+39 39878581', 273, '2022-02-03', 1947.71);
INSERT INTO valutazioni VALUES('+39 29395999', 227, '2022-02-09', 1155.29);
INSERT INTO valutazioni VALUES('+39 26456139', 296, '2022-04-12', 208.33);
INSERT INTO valutazioni VALUES('+39 58564300', 222, '2022-02-23', 1876.82);
INSERT INTO valutazioni VALUES('+39 73122373', 254, '2022-01-16', 9608.77);
INSERT INTO valutazioni VALUES('+39 77367952', 3, '2022-03-10', 8756.71);
INSERT INTO valutazioni VALUES('+39 23754873', 134, '2022-04-08', 9056.82);
INSERT INTO valutazioni VALUES('+39 26456139', 4, '2022-02-28', 9710.01);
INSERT INTO valutazioni VALUES('+39 99820747', 144, '2022-03-08', 6066.58);
INSERT INTO valutazioni VALUES('+39 18350889', 102, '2022-01-29', 2503.73);
INSERT INTO valutazioni VALUES('+39 18350889', 155, '2022-02-06', 9725.8);
INSERT INTO valutazioni VALUES('+39 24698683', 167, '2022-04-21', 6232.0);
INSERT INTO valutazioni VALUES('+39 99820747', 186, '2022-03-22', 4305.6);
INSERT INTO valutazioni VALUES('+39 78039697', 297, '2022-02-07', 1603.15);
INSERT INTO valutazioni VALUES('+39 01549070', 54, '2022-04-17', 8773.69);
INSERT INTO valutazioni VALUES('+39 40972876', 93, '2022-03-21', 7867.85);
INSERT INTO valutazioni VALUES('+39 95258856', 233, '2022-02-15', 8881.19);
INSERT INTO valutazioni VALUES('+39 78039697', 159, '2022-04-12', 9463.15);
INSERT INTO valutazioni VALUES('+39 21380020', 236, '2022-03-25', 7630.99);
INSERT INTO valutazioni VALUES('+39 33371966', 215, '2022-02-08', 531.38);
INSERT INTO valutazioni VALUES('+39 83181743', 105, '2022-01-04', 3673.87);
INSERT INTO valutazioni VALUES('+39 94946266', 183, '2022-02-18', 9253.01);
INSERT INTO valutazioni VALUES('+39 28857172', 5, '2022-01-22', 3991.25);
INSERT INTO valutazioni VALUES('+39 94946266', 56, '2022-02-03', 9406.47);
INSERT INTO valutazioni VALUES('+39 61489701', 262, '2022-04-07', 2919.86);
INSERT INTO valutazioni VALUES('+39 18350889', 122, '2022-01-02', 4294.22);
INSERT INTO valutazioni VALUES('+39 99820747', 92, '2022-04-03', 4286.15);
INSERT INTO valutazioni VALUES('+39 95530481', 152, '2022-02-17', 4680.61);
INSERT INTO valutazioni VALUES('+39 99820747', 110, '2022-03-24', 9458.66);
INSERT INTO valutazioni VALUES('+39 77367952', 215, '2022-03-04', 8258.84);
INSERT INTO valutazioni VALUES('+39 63395873', 184, '2022-03-03', 9846.91);
INSERT INTO valutazioni VALUES('+39 21488689', 267, '2022-01-09', 8498.24);
INSERT INTO valutazioni VALUES('+39 29395999', 203, '2022-02-05', 4083.82);
INSERT INTO valutazioni VALUES('+39 31571812', 117, '2022-02-28', 6357.55);
INSERT INTO valutazioni VALUES('+39 62430483', 63, '2022-02-26', 5779.69);
INSERT INTO transazioni VALUES(115, 98, 20891.8);
INSERT INTO transazioni VALUES(69, 18, 29770.88);
INSERT INTO transazioni VALUES(100, 99, 4880.37);
INSERT INTO transazioni VALUES(293, 73, 24220.95);
INSERT INTO transazioni VALUES(146, 46, 47844.34);
INSERT INTO transazioni VALUES(72, 30, 36282.3);
INSERT INTO transazioni VALUES(1, 13, 41558.58);
INSERT INTO transazioni VALUES(248, 4, 28917.3);
INSERT INTO transazioni VALUES(210, 64, 43528.49);
INSERT INTO transazioni VALUES(6, 88, 31369.63);
INSERT INTO transazioni VALUES(11, 44, 32216.41);
INSERT INTO transazioni VALUES(112, 3, 49310.76);
INSERT INTO transazioni VALUES(60, 77, 6171.14);
INSERT INTO transazioni VALUES(30, 23, 45735.85);
INSERT INTO transazioni VALUES(20, 25, 19134.46);
INSERT INTO transazioni VALUES(194, 75, 29678.74);
INSERT INTO transazioni VALUES(288, 90, 4261.53);
INSERT INTO transazioni VALUES(238, 83, 29796.12);
INSERT INTO transazioni VALUES(148, 71, 39581.75);
INSERT INTO transazioni VALUES(64, 35, 36904.59);
INSERT INTO transazioni VALUES(291, 51, 37206.45);
INSERT INTO transazioni VALUES(182, 40, 47674.6);
INSERT INTO transazioni VALUES(279, 76, 23165.23);
INSERT INTO transazioni VALUES(255, 100, 16206.97);
INSERT INTO transazioni VALUES(298, 10, 5579.5);
INSERT INTO transazioni VALUES(16, 20, 27458.8);
INSERT INTO transazioni VALUES(21, 63, 47453.19);
INSERT INTO transazioni VALUES(198, 70, 30782.51);
INSERT INTO transazioni VALUES(63, 12, 23671.96);
INSERT INTO transazioni VALUES(270, 56, 4669.05);
INSERT INTO transazioni VALUES(221, 89, 33568.61);
INSERT INTO transazioni VALUES(99, 84, 45346.56);
INSERT INTO transazioni VALUES(284, 97, 8194.15);
INSERT INTO transazioni VALUES(245, 50, 35075.87);
INSERT INTO transazioni VALUES(167, 96, 8521.46);
INSERT INTO transazioni VALUES(128, 16, 5199.88);
INSERT INTO transazioni VALUES(249, 62, 23076.35);
INSERT INTO transazioni VALUES(174, 91, 28626.08);
INSERT INTO transazioni VALUES(51, 28, 37997.45);
INSERT INTO transazioni VALUES(47, 72, 6869.72);
INSERT INTO transazioni VALUES(52, 1, 4808.42);
INSERT INTO transazioni VALUES(35, 80, 42442.34);
INSERT INTO transazioni VALUES(171, 32, 13541.46);
INSERT INTO transazioni VALUES(287, 14, 37516.03);
INSERT INTO transazioni VALUES(276, 15, 25373.4);
INSERT INTO transazioni VALUES(149, 49, 42046.82);
INSERT INTO transazioni VALUES(197, 93, 23669.96);
INSERT INTO transazioni VALUES(157, 61, 32951.58);
INSERT INTO transazioni VALUES(38, 82, 5969.07);
INSERT INTO transazioni VALUES(180, 68, 39265.68);
INSERT INTO transazioni VALUES(61, 55, 27504.18);
INSERT INTO transazioni VALUES(200, 7, 5449.39);
INSERT INTO transazioni VALUES(65, 8, 25009.5);
INSERT INTO transazioni VALUES(184, 59, 24063.68);
INSERT INTO transazioni VALUES(195, 38, 43752.02);
INSERT INTO transazioni VALUES(56, 67, 19061.06);
INSERT INTO transazioni VALUES(207, 22, 35910.47);
INSERT INTO transazioni VALUES(272, 94, 44923.03);
INSERT INTO transazioni VALUES(164, 29, 11390.54);
INSERT INTO transazioni VALUES(205, 33, 33488.83);
INSERT INTO transazioni VALUES(121, 34, 12611.4);
INSERT INTO transazioni VALUES(202, 11, 36804.92);
INSERT INTO transazioni VALUES(264, 85, 1486.37);
INSERT INTO transazioni VALUES(296, 58, 5982.11);
INSERT INTO transazioni VALUES(45, 5, 25344.49);
INSERT INTO transazioni VALUES(91, 9, 20738.05);
INSERT INTO transazioni VALUES(23, 69, 21305.83);
INSERT INTO transazioni VALUES(203, 47, 39917.37);
INSERT INTO transazioni VALUES(29, 37, 4868.06);
INSERT INTO transazioni VALUES(163, 17, 26261.44);
INSERT INTO transazioni VALUES(173, 92, 6836.24);
INSERT INTO transazioni VALUES(19, 66, 22808.96);
INSERT INTO transazioni VALUES(33, 95, 1167.74);
INSERT INTO transazioni VALUES(278, 60, 13455.63);
INSERT INTO transazioni VALUES(104, 2, 30909.97);
INSERT INTO transazioni VALUES(150, 65, 4673.32);
INSERT INTO transazioni VALUES(222, 53, 13558.49);
INSERT INTO transazioni VALUES(85, 36, 30763.25);
INSERT INTO transazioni VALUES(25, 81, 6858.7);
INSERT INTO transazioni VALUES(169, 52, 2104.38);
INSERT INTO transazioni VALUES(219, 19, 46954.91);
INSERT INTO transazioni VALUES(102, 6, 28830.12);
INSERT INTO transazioni VALUES(178, 54, 49762.26);
INSERT INTO transazioni VALUES(247, 42, 7662.59);
INSERT INTO transazioni VALUES(17, 41, 30979.76);
INSERT INTO transazioni VALUES(118, 78, 44102.26);
INSERT INTO transazioni VALUES(5, 26, 38251.79);
INSERT INTO transazioni VALUES(204, 86, 13289.05);
INSERT INTO transazioni VALUES(275, 21, 9814.24);
INSERT INTO transazioni VALUES(153, 39, 28578.32);
INSERT INTO transazioni VALUES(66, 43, 36874.53);
INSERT INTO transazioni VALUES(36, 27, 31228.29);
INSERT INTO transazioni VALUES(251, 48, 12095.39);
INSERT INTO transazioni VALUES(75, 57, 43139.59);
INSERT INTO transazioni VALUES(260, 24, 37522.15);
INSERT INTO transazioni VALUES(46, 79, 42051.56);
INSERT INTO transazioni VALUES(147, 87, 20548.17);
INSERT INTO transazioni VALUES(289, 45, 18724.1);
INSERT INTO transazioni VALUES(235, 74, 1474.51);
INSERT INTO transazioni VALUES(230, 31, 5228.95);
SET FOREIGN_KEY_CHECKS=1;