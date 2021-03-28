ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';
SET SERVEROUTPUT ON;

-- Zad 47
CREATE OR REPLACE TYPE KOCUR AS OBJECT (
  imie VARCHAR2(15),
  plec VARCHAR2(1),
  pseudo VARCHAR2(15),
  funkcja VARCHAR2(10),
  szef REF KOCUR,
  w_stadku_od DATE,
  przydzial_myszy NUMBER(3),
  myszy_extra NUMBER(3),
  nr_bandy NUMBER(2),
  MEMBER FUNCTION calkowite_spozycie RETURN NUMBER,
  MEMBER FUNCTION dane RETURN VARCHAR2,
  MAP MEMBER FUNCTION map_pseudo RETURN VARCHAR2
);

/

CREATE OR REPLACE TYPE BODY KOCUR
AS
  MEMBER FUNCTION calkowite_spozycie RETURN NUMBER
  IS
  BEGIN
    RETURN NVL(przydzial_myszy, 0) + NVL(myszy_extra, 0);
  END;

  MEMBER FUNCTION dane RETURN VARCHAR2
  IS
  BEGIN
    RETURN imie || ' (ps. ' || pseudo || '), plec ' || plec || ', funkcja ' || funkcja
    || ', w stadku od ' || w_stadku_od || ', banda nr ' || nr_bandy || ', dostaje '
    || SELF.calkowite_spozycie() || ' myszy';
  END;

  MAP MEMBER FUNCTION map_pseudo RETURN VARCHAR2
  IS
  BEGIN
    RETURN pseudo;
  END;
END;

/

CREATE TABLE KocuryO OF KOCUR (
  imie CONSTRAINT ko_i_nn NOT NULL,
  plec CONSTRAINT ko_p_ch CHECK(plec IN ('M', 'D')),
  pseudo CONSTRAINT ko_ps_pk PRIMARY KEY,
  funkcja CONSTRAINT ko_f_fk REFERENCES Funkcje(funkcja),
  szef SCOPE IS KocuryO,
  w_stadku_od DEFAULT SYSDATE,
  nr_bandy CONSTRAINT ko_nr_fk REFERENCES Bandy(nr_bandy)
);

/

CREATE OR REPLACE TYPE PLEBS AS OBJECT (
  nr_plebsu NUMBER(3),
  kot REF KOCUR,
  MEMBER FUNCTION dane_o_czlonku_plebsu RETURN VARCHAR2,
  MEMBER FUNCTION czy_powinien_awansowac RETURN BOOLEAN
);

/

CREATE OR REPLACE TYPE BODY PLEBS
AS
  MEMBER FUNCTION dane_o_czlonku_plebsu RETURN VARCHAR2
  IS
    odniesienie KOCUR;
  BEGIN
    SELECT DEREF(kot) INTO odniesienie FROM Dual;
    RETURN odniesienie.dane() || ', nalezy do plebsu';
  END;

  MEMBER FUNCTION czy_powinien_awansowac RETURN BOOLEAN
  IS
    odniesienie KOCUR;
  BEGIN
    SELECT DEREF(kot) INTO odniesienie FROM Dual;
    RETURN odniesienie.w_stadku_od < '2008-01-01' AND NVL(odniesienie.myszy_extra, 0) > 10;
  END;
END;

/

CREATE TABLE PlebsO OF PLEBS (
  nr_plebsu CONSTRAINT po_n_pk PRIMARY KEY,
  kot SCOPE IS KocuryO CONSTRAINT po_k_nn NOT NULL
);

/

CREATE OR REPLACE TYPE ELITA AS OBJECT (
  nr_elity NUMBER(3),
  kot REF KOCUR,
  sluga REF PLEBS,
  MEMBER FUNCTION dane_o_czlonku_elity RETURN VARCHAR2,
  MEMBER FUNCTION czy_szef_slugi RETURN BOOLEAN
);

/

CREATE OR REPLACE TYPE BODY ELITA
AS
  MEMBER FUNCTION dane_o_czlonku_elity RETURN VARCHAR2
  IS
    odniesienie KOCUR;
  BEGIN
    SELECT DEREF(kot) INTO odniesienie FROM Dual;
    RETURN odniesienie.dane() || ', nalezy do elity';
  END;

  MEMBER FUNCTION czy_szef_slugi RETURN BOOLEAN
  IS
    odniesienie KOCUR;
  BEGIN
    SELECT DEREF(DEREF(sluga).kot) INTO odniesienie FROM Dual;
    RETURN kot = odniesienie.szef;
  END;
END;

/

CREATE TABLE ElitaO OF ELITA (
  nr_elity CONSTRAINT eo_n_pk PRIMARY KEY,
  kot SCOPE IS KocuryO CONSTRAINT eo_k_nn NOT NULL,
  sluga SCOPE IS PlebsO
);

/

CREATE OR REPLACE TYPE INCYDENT AS OBJECT (
  nr_incydentu NUMBER(3),
  kot REF KOCUR,
  imie_wroga VARCHAR2(15),
  data_incydentu DATE,
  opis_incydentu VARCHAR2(50),
  MEMBER FUNCTION czy_przedawniony RETURN BOOLEAN,
  MEMBER FUNCTION czy_udokumentowany RETURN BOOLEAN
);

/

CREATE OR REPLACE TYPE BODY INCYDENT
AS
  MEMBER FUNCTION czy_przedawniony RETURN BOOLEAN
  IS
  BEGIN
    RETURN data_incydentu < '2007-01-01';
  END;

  MEMBER FUNCTION czy_udokumentowany RETURN BOOLEAN
  IS
  BEGIN
    RETURN opis_incydentu IS NOT NULL;
  END;
END;

/

CREATE TABLE IncydentyO OF INCYDENT (
  nr_incydentu CONSTRAINT io_n_pk PRIMARY KEY,
  kot SCOPE IS KocuryO CONSTRAINT io_k_nn NOT NULL,
  imie_wroga CONSTRAINT io_iw_fk REFERENCES Wrogowie(imie_wroga),
  data_incydentu CONSTRAINT io_d_nn NOT NULL
);

/

CREATE OR REPLACE TYPE WPIS AS OBJECT (
  nr_wpisu NUMBER(3),
  wlasciciel REF ELITA,
  data_wprowadzenia DATE,
  data_usuniecia DATE,
  MEMBER FUNCTION czy_usunieta RETURN BOOLEAN,
  MEMBER FUNCTION odsetki RETURN NUMBER
);

/

CREATE OR REPLACE TYPE BODY WPIS
AS
  MEMBER FUNCTION czy_usunieta RETURN BOOLEAN
  IS
  BEGIN
    RETURN data_usuniecia IS NOT NULL;
  END;

  MEMBER FUNCTION odsetki RETURN NUMBER
  IS
  BEGIN
    IF data_usuniecia IS NULL THEN
      RETURN FLOOR(MONTHS_BETWEEN(CURRENT_DATE, data_wprowadzenia) / 12);
    ELSE
      RETURN 0;
    END IF;
  END;
END;

/

CREATE TABLE KontaO OF WPIS (
  nr_wpisu CONSTRAINT ko_n_pk PRIMARY KEY,
  wlasciciel SCOPE IS ElitaO CONSTRAINT ko_w_nn NOT NULL,
  data_wprowadzenia CONSTRAINT ko_dw_nn NOT NULL,
  CONSTRAINT ko_dw_du_ch CHECK(data_wprowadzenia <= data_usuniecia)
);

/

-- Sprawdzanie czy dodawana elita nie jest w plebsie i czy rekordy sa unikatowe
CREATE OR REPLACE TRIGGER Ograniczenia_elity
BEFORE INSERT OR UPDATE ON ElitaO
FOR EACH ROW
DECLARE
  liczba_istniejacych NUMBER;
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  SELECT COUNT(nr_plebsu) INTO liczba_istniejacych
  FROM PlebsO P
  WHERE P.kot = :NEW.kot;

  IF liczba_istniejacych > 0 THEN
    RAISE_APPLICATION_ERROR(-20001, 'Ten kot nalezy juz do plebsu');
  END IF;

  SELECT COUNT(nr_elity) INTO liczba_istniejacych
  FROM ElitaO E
  WHERE E.kot = :NEW.kot;

  IF liczba_istniejacych > 0 THEN
    RAISE_APPLICATION_ERROR(-20002, 'Ten kot nalezy juz do elity');
  END IF;
END;

/

-- Sprawdzanie czy dodawany plebs nie jest w elicie i czy rekordy sa unikatowe
CREATE OR REPLACE TRIGGER Ograniczenia_plebsu
BEFORE INSERT OR UPDATE ON PlebsO
FOR EACH ROW
DECLARE
  liczba_istniejacych NUMBER;
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  SELECT COUNT(nr_elity) INTO liczba_istniejacych
  FROM ElitaO E
  WHERE E.kot = :NEW.kot;

  IF liczba_istniejacych > 0 THEN
    RAISE_APPLICATION_ERROR(-20003, 'Ten kot nalezy juz do elity');
  END IF;

  SELECT COUNT(nr_plebsu) INTO liczba_istniejacych
  FROM PlebsO P
  WHERE P.kot = :NEW.kot;

  IF liczba_istniejacych > 0 THEN
    RAISE_APPLICATION_ERROR(-20004, 'Ten kot nalezy juz do plebsu');
  END IF;
END;

/

-- Sprawdzanie unikalnosci w IncydentyO
CREATE OR REPLACE TRIGGER Unikatowe_incydenty
BEFORE INSERT OR UPDATE ON IncydentyO
FOR EACH ROW
DECLARE
  liczba_istniejacych NUMBER;
  PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
  SELECT COUNT(nr_incydentu) INTO liczba_istniejacych
  FROM IncydentyO I
  WHERE I.kot = :NEW.kot AND I.imie_wroga = :NEW.imie_wroga;

  IF liczba_istniejacych > 0 THEN
    RAISE_APPLICATION_ERROR(-20005, 'Taki incydent juz istnieje');
  END IF;
END;

/

INSERT INTO KocuryO VALUES (KOCUR('MRUCZEK','M','TYGRYS','SZEFUNIO',NULL,'2002-01-01',103,33,1));
INSERT INTO KocuryO VALUES (KOCUR('BOLEK','M','LYSY','BANDZIOR',(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'TYGRYS'),'2006-08-15',72,21,2));
INSERT INTO KocuryO VALUES (KOCUR('KOREK','M','ZOMBI','BANDZIOR',(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'TYGRYS'),'2004-03-16',75,13,3));
INSERT INTO KocuryO VALUES (KOCUR('PUNIA','D','KURKA','LOWCZY',(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'ZOMBI'),'2008-01-01',61,NULL,3));
INSERT INTO KocuryO VALUES (KOCUR('PUCEK','M','RAFA','LOWCZY',(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'TYGRYS'),'2006-10-15',65,NULL,4));


INSERT ALL
  INTO KocuryO VALUES (KOCUR('MICKA','D','LOLA','MILUSIA',(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'TYGRYS'),'2009-10-14',25,47,1))
  INTO KocuryO VALUES (KOCUR('CHYTRY','M','BOLEK','DZIELCZY',(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'TYGRYS'),'2002-05-05',50,NULL,1))
  INTO KocuryO VALUES (KOCUR('RUDA','D','MALA','MILUSIA',(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'TYGRYS'),'2006-09-17',22,42,1))
  INTO KocuryO VALUES (KOCUR('JACEK','M','PLACEK','LOWCZY',(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'LYSY'),'2008-12-01',67,NULL,2))
  INTO KocuryO VALUES (KOCUR('BARI','M','RURA','LAPACZ',(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'LYSY'),'2009-09-01',56,NULL,2))
  INTO KocuryO VALUES (KOCUR('ZUZIA','D','SZYBKA','LOWCZY',(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'LYSY'),'2006-07-21',65,NULL,2))
  INTO KocuryO VALUES (KOCUR('BELA','D','LASKA','MILUSIA',(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'LYSY'),'2008-02-01',24,28,2))
  INTO KocuryO VALUES (KOCUR('SONIA','D','PUSZYSTA','MILUSIA',(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'ZOMBI'),'2010-11-18',20,35,3))
  INTO KocuryO VALUES (KOCUR('LUCEK','M','ZERO','KOT',(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'KURKA'),'2010-03-01',43,NULL,3))
  INTO KocuryO VALUES (KOCUR('LATKA','D','UCHO','KOT',(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'RAFA'),'2011-01-01',40,NULL,4))
  INTO KocuryO VALUES (KOCUR('DUDEK','M','MALY','KOT',(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'RAFA'),'2011-05-15',40,NULL,4))
  INTO KocuryO VALUES (KOCUR('KSAWERY','M','MAN','LAPACZ',(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'RAFA'),'2008-07-12',51,NULL,4))
  INTO KocuryO VALUES (KOCUR('MELA','D','DAMA','LAPACZ',(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'RAFA'),'2008-11-01',51,NULL,4))
SELECT * FROM Dual;

INSERT INTO PlebsO
  SELECT PLEBS(ROWNUM, REF(K))
  FROM KocuryO K
  WHERE K.funkcja IN ('KOT', 'BANDZIOR', 'LAPACZ', 'LOWCZY');

INSERT ALL
  INTO ElitaO VALUES (ELITA(1,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'TYGRYS'),(SELECT REF(P) FROM PlebsO P WHERE P.kot.pseudo = 'LYSY')))
  INTO ElitaO VALUES (ELITA(2,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'BOLEK'),NULL))
  INTO ElitaO VALUES (ELITA(3,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'LOLA'),(SELECT REF(P) FROM PlebsO P WHERE P.kot.pseudo = 'ZOMBI')))
  INTO ElitaO VALUES (ELITA(4,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'MALA'),(SELECT REF(P) FROM PlebsO P WHERE P.kot.pseudo = 'RAFA')))
  INTO ElitaO VALUES (ELITA(5,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'LASKA'),(SELECT REF(P) FROM PlebsO P WHERE P.kot.pseudo = 'PLACEK')))
  INTO ElitaO VALUES (ELITA(6,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'PUSZYSTA'),(SELECT REF(P) FROM PlebsO P WHERE P.kot.pseudo = 'RURA')))
SELECT * FROM Dual;

INSERT ALL
  INTO IncydentyO VALUES (INCYDENT(1,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'TYGRYS'),'KAZIO','2004-10-13','USILOWAL NABIC NA WIDLY'))
  INTO IncydentyO VALUES (INCYDENT(2,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'ZOMBI'),'SWAWOLNY DYZIO','2005-03-07','WYBIL OKO Z PROCY'))
  INTO IncydentyO VALUES (INCYDENT(3,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'BOLEK'),'KAZIO','2005-03-29','POSZCZUL BURKIEM'))
  INTO IncydentyO VALUES (INCYDENT(4,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'SZYBKA'),'GLUPIA ZOSKA','2006-09-12','UZYLA KOTA JAKO SCIERKI'))
  INTO IncydentyO VALUES (INCYDENT(5,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'MALA'),'CHYTRUSEK','2007-03-07','ZALECAL SIE'))
  INTO IncydentyO VALUES (INCYDENT(6,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'TYGRYS'),'DZIKI BILL','2007-06-12','USILOWAL POZBAWIC ZYCIA'))
  INTO IncydentyO VALUES (INCYDENT(7,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'BOLEK'),'DZIKI BILL','2007-11-10','ODGRYZL UCHO'))
  INTO IncydentyO VALUES (INCYDENT(8,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'LASKA'),'DZIKI BILL','2008-12-12','POGRYZL ZE LEDWO SIE WYLIZALA'))
  INTO IncydentyO VALUES (INCYDENT(9,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'LASKA'),'KAZIO','2009-01-07','ZLAPAL ZA OGON I ZROBIL WIATRAK'))
  INTO IncydentyO VALUES (INCYDENT(10,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'DAMA'),'KAZIO','2009-02-07','CHCIAL OBEDRZEC ZE SKORY'))
  INTO IncydentyO VALUES (INCYDENT(11,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'MAN'),'REKSIO','2009-04-14','WYJATKOWO NIEGRZECZNIE OBSZCZEKAL'))
  INTO IncydentyO VALUES (INCYDENT(12,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'LYSY'),'BETHOVEN','2009-05-11','NIE PODZIELIL SIE SWOJA KASZA'))
  INTO IncydentyO VALUES (INCYDENT(13,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'RURA'),'DZIKI BILL','2009-09-03','ODGRYZL OGON'))
  INTO IncydentyO VALUES (INCYDENT(14,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'PLACEK'),'BAZYLI','2010-07-12','DZIOBIAC UNIEMOZLIWIL PODEBRANIE KURCZAKA'))
  INTO IncydentyO VALUES (INCYDENT(15,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'PUSZYSTA'),'SMUKLA','2010-11-19','OBRZUCILA SZYSZKAMI'))
  INTO IncydentyO VALUES (INCYDENT(16,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'KURKA'),'BUREK','2010-12-14','POGONIL'))
  INTO IncydentyO VALUES (INCYDENT(17,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'MALY'),'CHYTRUSEK','2011-07-13','PODEBRAL PODEBRANE JAJKA'))
  INTO IncydentyO VALUES (INCYDENT(18,(SELECT REF(K) FROM KocuryO K WHERE K.pseudo = 'UCHO'),'SWAWOLNY DYZIO','2011-07-14','OBRZUCIL KAMIENIAMI'))
SELECT * FROM Dual;

INSERT ALL
  INTO KontaO VALUES (WPIS(1,(SELECT REF(E) FROM ElitaO E WHERE E.kot.pseudo = 'TYGRYS'), SYSDATE, NULL))
  INTO KontaO VALUES (WPIS(2,(SELECT REF(E) FROM ElitaO E WHERE E.kot.pseudo = 'TYGRYS'), '2019-04-10', '2020-03-11'))
  INTO KontaO VALUES (WPIS(3,(SELECT REF(E) FROM ElitaO E WHERE E.kot.pseudo = 'TYGRYS'), '2018-05-15', '2018-06-01'))
  INTO KontaO VALUES (WPIS(4,(SELECT REF(E) FROM ElitaO E WHERE E.kot.pseudo = 'TYGRYS'), '2020-09-28', NULL))
  INTO KontaO VALUES (WPIS(5,(SELECT REF(E) FROM ElitaO E WHERE E.kot.pseudo = 'BOLEK'), '2020-12-12', '2021-01-15'))
  INTO KontaO VALUES (WPIS(6,(SELECT REF(E) FROM ElitaO E WHERE E.kot.pseudo = 'BOLEK'), '2021-01-22', NULL))
  INTO KontaO VALUES (WPIS(7,(SELECT REF(E) FROM ElitaO E WHERE E.kot.pseudo = 'BOLEK'), SYSDATE, NULL))
  INTO KontaO VALUES (WPIS(8,(SELECT REF(E) FROM ElitaO E WHERE E.kot.pseudo = 'LOLA'), SYSDATE, NULL))
  INTO KontaO VALUES (WPIS(9,(SELECT REF(E) FROM ElitaO E WHERE E.kot.pseudo = 'LOLA'), '2020-10-10', '2021-01-01'))
  INTO KontaO VALUES (WPIS(10,(SELECT REF(E) FROM ElitaO E WHERE E.kot.pseudo = 'LOLA'), '2020-12-29', NULL))
  INTO KontaO VALUES (WPIS(11,(SELECT REF(E) FROM ElitaO E WHERE E.kot.pseudo = 'MALA'), SYSDATE, NULL))
  INTO KontaO VALUES (WPIS(12,(SELECT REF(E) FROM ElitaO E WHERE E.kot.pseudo = 'MALA'), '2021-01-10', NULL))
  INTO KontaO VALUES (WPIS(13,(SELECT REF(E) FROM ElitaO E WHERE E.kot.pseudo = 'LASKA'), '2017-10-12', '2018-03-30'))
  INTO KontaO VALUES (WPIS(14,(SELECT REF(E) FROM ElitaO E WHERE E.kot.pseudo = 'LASKA'), '2016-07-12', '2016-09-13'))
  INTO KontaO VALUES (WPIS(15,(SELECT REF(E) FROM ElitaO E WHERE E.kot.pseudo = 'LASKA'), '2015-07-22', '2015-10-14'))
SELECT * FROM Dual;

/

-- Referencja jako realizacja zlaczenia
SELECT K.wlasciciel.kot.pseudo, K.wlasciciel.kot.przydzial_myszy,
       K.wlasciciel.kot.myszy_extra, data_wprowadzenia, data_usuniecia
FROM KontaO K;

SELECT K.pseudo, nr_wpisu, data_wprowadzenia, data_usuniecia
FROM KocuryO K JOIN ElitaO E ON REF(K) = E.kot LEFT JOIN KontaO ON REF(E) = KontaO.wlasciciel;

-- Podzapytanie
SELECT K.dane()
FROM KocuryO K
WHERE K.calkowite_spozycie() > (
                                SELECT AVG(K1.calkowite_spozycie())
                                FROM KocuryO K1
                               );

-- Grupowanie
SELECT K.wlasciciel.kot, K.wlasciciel.kot.dane(), COUNT(nr_wpisu)
FROM KontaO K
GROUP BY K.wlasciciel.kot
ORDER BY K.wlasciciel.kot;

/

-- Zad 18
SELECT K.imie, K.w_stadku_od "POLUJE OD"
FROM KocuryO K JOIN KocuryO K2 ON K2.imie = 'JACEK'
WHERE K.w_stadku_od < K2.w_stadku_od
ORDER BY K.w_stadku_od DESC;

-- Zad 22
SELECT I.kot.funkcja "Funkcja", I.kot.pseudo "Pseudonim kota",
       COUNT(nr_incydentu) "Liczba wrogow"
FROM IncydentyO I
GROUP BY I.kot.funkcja, I.kot.pseudo
HAVING COUNT(nr_incydentu) > 1;

/

-- Zad 34
DECLARE
  szukana KocuryO.funkcja % TYPE := '&funkcja';
  f KocuryO.funkcja % TYPE;
BEGIN
  SELECT MIN(funkcja) INTO f FROM KocuryO WHERE funkcja = szukana;
  IF f IS NULL
  THEN DBMS_OUTPUT.PUT_LINE('Nie znaleziono kota o podanej funkcji');
  ELSE DBMS_OUTPUT.PUT_LINE('Znaleziono kota o funkcji ' || f);
  END IF;
END;

/

-- Zad 35
DECLARE
  szukany KocuryO.pseudo % TYPE := '&pseudo';
  imie KocuryO.imie % TYPE;
  przydzial NUMBER;
  miesiac NUMBER(2);
BEGIN
  SELECT imie, (NVL(przydzial_myszy, 0) + NVL(myszy_extra, 0)) * 12, EXTRACT(MONTH FROM w_stadku_od)
  INTO imie, przydzial, miesiac FROM KocuryO WHERE pseudo = szukany;

  IF przydzial > 700 THEN DBMS_OUTPUT.PUT_LINE('calkowity roczny przydzial myszy >700');
  ELSIF imie LIKE '%A%' THEN DBMS_OUTPUT.PUT_LINE('imie zawiera litere A');
  ELSIF miesiac = 5 THEN DBMS_OUTPUT.PUT_LINE('maj jest miesiacem przystapienia do stada');
  ELSE DBMS_OUTPUT.PUT_LINE('nie odpowiada kryteriom');
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN DBMS_OUTPUT.PUT_LINE('Nie znaleziono kota o podanym pseudonimie');
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;

/






-- Zad 48

CREATE TABLE PlebsT (
  nr_plebsu NUMBER(3) CONSTRAINT p_np_pk PRIMARY KEY,
  pseudo VARCHAR2(15) CONSTRAINT p_p_fk REFERENCES Kocury(pseudo)
                      CONSTRAINT p_p_u UNIQUE
                      CONSTRAINT p_p_nn NOT NULL
);

CREATE TABLE ElitaT (
  nr_elity NUMBER(3) CONSTRAINT e_ne_pk PRIMARY KEY,
  pseudo VARCHAR2(15) CONSTRAINT e_p_fk REFERENCES Kocury(pseudo)
                      CONSTRAINT e_p_u UNIQUE
                      CONSTRAINT e_p_nn NOT NULL,
  nr_slugi NUMBER(3) CONSTRAINT e_s_fk REFERENCES PlebsT(nr_plebsu)
);

CREATE TABLE KontaT (
  nr_wpisu NUMBER(3) CONSTRAINT k_nw_pk PRIMARY KEY,
  nr_elity NUMBER(3) CONSTRAINT k_p_fk REFERENCES ElitaT(nr_elity)
                     CONSTRAINT k_p_nn NOT NULL,
  data_wprowadzenia DATE CONSTRAINT k_dw_nn NOT NULL,
  data_usuniecia DATE,
  CONSTRAINT k_dw_du_ch CHECK(data_wprowadzenia <= data_usuniecia)
);

/

-- Sprawdzanie czy dodawana elita nie jest w plebsie
CREATE OR REPLACE TRIGGER Ograniczenia_elity2
BEFORE INSERT OR UPDATE ON ElitaT
FOR EACH ROW
DECLARE
  liczba_istniejacych NUMBER;
BEGIN
  SELECT COUNT(nr_plebsu) INTO liczba_istniejacych
  FROM PlebsT P
  WHERE P.pseudo = :NEW.pseudo;

  IF liczba_istniejacych > 0 THEN
    RAISE_APPLICATION_ERROR(-20006, 'Ten kot nalezy juz do plebsu');
  END IF;
END;

/

-- Sprawdzanie czy dodawany plebs nie jest w elicie
CREATE OR REPLACE TRIGGER Ograniczenia_plebsu2
BEFORE INSERT OR UPDATE ON PlebsT
FOR EACH ROW
DECLARE
  liczba_istniejacych NUMBER;
BEGIN
  SELECT COUNT(nr_elity) INTO liczba_istniejacych
  FROM ElitaT E
  WHERE E.pseudo = :NEW.pseudo;

  IF liczba_istniejacych > 0 THEN
    RAISE_APPLICATION_ERROR(-20007, 'Ten kot nalezy juz do elity');
  END IF;
END;

/

CREATE OR REPLACE FORCE VIEW KocuryV OF KOCUR
WITH OBJECT IDENTIFIER (pseudo) AS
  SELECT imie, plec, pseudo, funkcja, MAKE_REF(KocuryV, szef) szef,
         w_stadku_od, przydzial_myszy, myszy_extra, nr_bandy
  FROM Kocury;

CREATE OR REPLACE VIEW PlebsV OF PLEBS
WITH OBJECT IDENTIFIER (nr_plebsu) AS
  SELECT nr_plebsu, MAKE_REF(KocuryV, pseudo) kot
  FROM PlebsT;

CREATE OR REPLACE VIEW ElitaV OF ELITA
WITH OBJECT IDENTIFIER (nr_elity) AS
  SELECT nr_elity, MAKE_REF(KocuryV, pseudo) kot,
         MAKE_REF(PlebsV, nr_slugi) sluga
  FROM ElitaT;

CREATE OR REPLACE VIEW IncydentyV OF INCYDENT
WITH OBJECT IDENTIFIER (nr_incydentu) AS
  SELECT ROW_NUMBER() OVER (ORDER BY data_incydentu) nr_incydentu,
         MAKE_REF(KocuryV, pseudo) kot, imie_wroga, data_incydentu, opis_incydentu
  FROM Wrogowie_Kocurow;

CREATE OR REPLACE VIEW KontaV OF WPIS
WITH OBJECT IDENTIFIER (nr_wpisu) AS
  SELECT nr_wpisu, MAKE_REF(ElitaV, nr_elity) kot, data_wprowadzenia, data_usuniecia
  FROM KontaT;

/

INSERT INTO PlebsV
  SELECT PLEBS(ROWNUM, REF(K))
  FROM KocuryV K
  WHERE K.funkcja IN ('KOT', 'BANDZIOR', 'LAPACZ', 'LOWCZY');

INSERT INTO ElitaV VALUES (ELITA(1,(SELECT REF(K) FROM KocuryV K WHERE K.pseudo = 'TYGRYS'),(SELECT REF(P) FROM PlebsV P WHERE P.kot.pseudo = 'LYSY')));
INSERT INTO ElitaV VALUES (ELITA(2,(SELECT REF(K) FROM KocuryV K WHERE K.pseudo = 'BOLEK'),NULL));
INSERT INTO ElitaV VALUES (ELITA(3,(SELECT REF(K) FROM KocuryV K WHERE K.pseudo = 'LOLA'),(SELECT REF(P) FROM PlebsV P WHERE P.kot.pseudo = 'ZOMBI')));
INSERT INTO ElitaV VALUES (ELITA(4,(SELECT REF(K) FROM KocuryV K WHERE K.pseudo = 'MALA'),(SELECT REF(P) FROM PlebsV P WHERE P.kot.pseudo = 'RAFA')));
INSERT INTO ElitaV VALUES (ELITA(5,(SELECT REF(K) FROM KocuryV K WHERE K.pseudo = 'LASKA'),(SELECT REF(P) FROM PlebsV P WHERE P.kot.pseudo = 'PLACEK')));
INSERT INTO ElitaV VALUES (ELITA(6,(SELECT REF(K) FROM KocuryV K WHERE K.pseudo = 'PUSZYSTA'),(SELECT REF(P) FROM PlebsV P WHERE P.kot.pseudo = 'RURA')));

INSERT INTO KontaV VALUES (WPIS(1,(SELECT REF(E) FROM ElitaV E WHERE E.kot.pseudo = 'TYGRYS'), SYSDATE, NULL));
INSERT INTO KontaV VALUES (WPIS(2,(SELECT REF(E) FROM ElitaV E WHERE E.kot.pseudo = 'TYGRYS'), '2019-04-10', '2020-03-11'));
INSERT INTO KontaV VALUES (WPIS(3,(SELECT REF(E) FROM ElitaV E WHERE E.kot.pseudo = 'TYGRYS'), '2018-05-15', '2018-06-01'));
INSERT INTO KontaV VALUES (WPIS(4,(SELECT REF(E) FROM ElitaV E WHERE E.kot.pseudo = 'TYGRYS'), '2020-09-28', NULL));
INSERT INTO KontaV VALUES (WPIS(5,(SELECT REF(E) FROM ElitaV E WHERE E.kot.pseudo = 'BOLEK'), '2020-12-12', '2021-01-15'));
INSERT INTO KontaV VALUES (WPIS(6,(SELECT REF(E) FROM ElitaV E WHERE E.kot.pseudo = 'BOLEK'), '2021-01-22', NULL));
INSERT INTO KontaV VALUES (WPIS(7,(SELECT REF(E) FROM ElitaV E WHERE E.kot.pseudo = 'BOLEK'), SYSDATE, NULL));
INSERT INTO KontaV VALUES (WPIS(8,(SELECT REF(E) FROM ElitaV E WHERE E.kot.pseudo = 'LOLA'), SYSDATE, NULL));
INSERT INTO KontaV VALUES (WPIS(9,(SELECT REF(E) FROM ElitaV E WHERE E.kot.pseudo = 'LOLA'), '2020-10-10', '2021-01-01'));
INSERT INTO KontaV VALUES (WPIS(10,(SELECT REF(E) FROM ElitaV E WHERE E.kot.pseudo = 'LOLA'), '2020-12-29', NULL));
INSERT INTO KontaV VALUES (WPIS(11,(SELECT REF(E) FROM ElitaV E WHERE E.kot.pseudo = 'MALA'), SYSDATE, NULL));
INSERT INTO KontaV VALUES (WPIS(12,(SELECT REF(E) FROM ElitaV E WHERE E.kot.pseudo = 'MALA'), '2021-01-10', NULL));
INSERT INTO KontaV VALUES (WPIS(13,(SELECT REF(E) FROM ElitaV E WHERE E.kot.pseudo = 'LASKA'), '2017-10-12', '2018-03-30'));
INSERT INTO KontaV VALUES (WPIS(14,(SELECT REF(E) FROM ElitaV E WHERE E.kot.pseudo = 'LASKA'), '2016-07-12', '2016-09-13'));
INSERT INTO KontaV VALUES (WPIS(15,(SELECT REF(E) FROM ElitaV E WHERE E.kot.pseudo = 'LASKA'), '2015-07-22', '2015-10-14'));

/

-- Referencja jako realizacja zlaczenia
SELECT K.wlasciciel.kot.pseudo, K.wlasciciel.kot.przydzial_myszy,
       K.wlasciciel.kot.myszy_extra, data_wprowadzenia, data_usuniecia
FROM KontaV K;

SELECT K.pseudo, nr_wpisu, data_wprowadzenia, data_usuniecia
FROM KocuryV K JOIN ElitaV E ON REF(K) = E.kot LEFT JOIN KontaV ON REF(E) = KontaV.wlasciciel;

-- Podzapytanie
SELECT K.dane()
FROM KocuryV K
WHERE K.calkowite_spozycie() > (
                                SELECT AVG(K1.calkowite_spozycie())
                                FROM KocuryV K1
                               );

-- Grupowanie
SELECT K.wlasciciel.kot, K.wlasciciel.kot.dane(), COUNT(nr_wpisu)
FROM KontaV K
GROUP BY K.wlasciciel.kot
ORDER BY K.wlasciciel.kot;

/

-- Zad 18
SELECT K.imie, K.w_stadku_od "POLUJE OD"
FROM KocuryV K JOIN KocuryV K2 ON K2.imie = 'JACEK'
WHERE K.w_stadku_od < K2.w_stadku_od
ORDER BY K.w_stadku_od DESC;

-- Zad 22
SELECT I.kot.funkcja "Funkcja", I.kot.pseudo "Pseudonim kota",
       COUNT(nr_incydentu) "Liczba wrogow"
FROM IncydentyV I
GROUP BY I.kot.funkcja, I.kot.pseudo
HAVING COUNT(nr_incydentu) > 1;

/

-- Zad 34
DECLARE
  szukana KocuryV.funkcja % TYPE := '&funkcja';
  f KocuryV.funkcja % TYPE;
BEGIN
  SELECT MIN(funkcja) INTO f FROM KocuryV WHERE funkcja = szukana;
  IF f IS NULL
  THEN DBMS_OUTPUT.PUT_LINE('Nie znaleziono kota o podanej funkcji');
  ELSE DBMS_OUTPUT.PUT_LINE('Znaleziono kota o funkcji ' || f);
  END IF;
END;

/

-- Zad 35
DECLARE
  szukany KocuryV.pseudo % TYPE := '&pseudo';
  imie KocuryV.imie % TYPE;
  przydzial NUMBER;
  miesiac NUMBER(2);
BEGIN
  SELECT imie, (NVL(przydzial_myszy, 0) + NVL(myszy_extra, 0)) * 12, EXTRACT(MONTH FROM w_stadku_od)
  INTO imie, przydzial, miesiac FROM KocuryV WHERE pseudo = szukany;

  IF przydzial > 700 THEN DBMS_OUTPUT.PUT_LINE('calkowity roczny przydzial myszy >700');
  ELSIF imie LIKE '%A%' THEN DBMS_OUTPUT.PUT_LINE('imie zawiera litere A');
  ELSIF miesiac = 5 THEN DBMS_OUTPUT.PUT_LINE('maj jest miesiacem przystapienia do stada');
  ELSE DBMS_OUTPUT.PUT_LINE('nie odpowiada kryteriom');
  END IF;
EXCEPTION
  WHEN NO_DATA_FOUND THEN DBMS_OUTPUT.PUT_LINE('Nie znaleziono kota o podanym pseudonimie');
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;

/

DROP VIEW KontaV;
DROP VIEW IncydentyV;
DROP VIEW ElitaV;
DROP VIEW PlebsV;
DROP VIEW KocuryV;
DROP TABLE KontaT;
DROP TABLE ElitaT;
DROP TABLE PlebsT;
DROP TRIGGER Unikatowe_incydenty;
DROP TRIGGER Ograniczenia_plebsu;
DROP TRIGGER Ograniczenia_elity;
DROP TABLE KontaO;
DROP TABLE IncydentyO;
DROP TABLE ElitaO;
DROP TABLE PlebsO;
DROP TABLE KocuryO;
DROP TYPE BODY WPIS;
DROP TYPE WPIS;
DROP TYPE BODY INCYDENT;
DROP TYPE INCYDENT;
DROP TYPE BODY ELITA;
DROP TYPE ELITA;
DROP TYPE BODY PLEBS;
DROP TYPE PLEBS;
DROP TYPE BODY KOCUR;
DROP TYPE KOCUR;

/






-- Zad 49
BEGIN
  EXECUTE IMMEDIATE 'CREATE TABLE Myszy (
    nr_myszy NUMBER CONSTRAINT m_nm_pk PRIMARY KEY,
    lowca VARCHAR2(15) CONSTRAINT m_l_fk REFERENCES Kocury(pseudo)
                      CONSTRAINT m_l_nn NOT NULL,
    zjadacz VARCHAR2(15) CONSTRAINT m_z_fk REFERENCES Kocury(pseudo),
    waga_myszy NUMBER CONSTRAINT m_wm_nn NOT NULL
                      CONSTRAINT m_wm_ch CHECK(waga_myszy BETWEEN 15 AND 35),
    data_zlowienia DATE CONSTRAINT m_dz_nn NOT NULL,
    data_wydania DATE,
    CONSTRAINT m_dz_dw_ch CHECK(data_zlowienia <= data_wydania)
  )';
END;

/

DECLARE
  start_date DATE := '2004-01-01';
  next_date DATE;
  end_date DATE := '2021-01-26';
  sroda DATE;
  next_sroda DATE;
  srednia NUMBER;
  suma NUMBER := 0;
  myszy_danego_kota NUMBER;
  i NUMBER;
  do_wydania NUMBER;

  TYPE kocury_table_type IS TABLE OF Kocury % ROWTYPE INDEX BY BINARY_INTEGER;
  kocury_table kocury_table_type;
  kocury_i BINARY_INTEGER := 1;

  TYPE myszy_table_type IS TABLE OF Myszy % ROWTYPE INDEX BY BINARY_INTEGER;
  myszy_table myszy_table_type;
  myszy_i BINARY_INTEGER := 1;
  myszy_i_previous NUMBER := 1;
BEGIN
  EXECUTE IMMEDIATE 'SELECT * FROM Kocury ORDER BY w_stadku_od'
  BULK COLLECT INTO kocury_table;

  sroda := NEXT_DAY(LAST_DAY(start_date) - 7, 'środa');
  next_date := ADD_MONTHS(start_date, 1);
  next_sroda := NEXT_DAY(LAST_DAY(next_date) - 7, 'środa');

  WHILE next_date <= end_date
  LOOP
    -- Sprawdzanie czy nowe koty dolaczyly do stada
    WHILE kocury_i <= kocury_table.COUNT AND kocury_table(kocury_i).w_stadku_od <= start_date
    LOOP
      suma := suma + NVL(kocury_table(kocury_i).przydzial_myszy, 0) + NVL(kocury_table(kocury_i).myszy_extra, 0);
      srednia := ROUND(suma / kocury_i);
      kocury_i := kocury_i + 1;
    END LOOP;

    -- Wpisywanie nowych zlapanych myszy
    FOR i IN 1..(kocury_i - 1)
    LOOP
      myszy_danego_kota := 0;
      WHILE myszy_danego_kota < srednia
      LOOP
        myszy_table(myszy_i).nr_myszy := myszy_i;
        myszy_table(myszy_i).lowca := kocury_table(i).pseudo;
        myszy_table(myszy_i).waga_myszy := ROUND(DBMS_RANDOM.VALUE(15, 35), 2);
        myszy_table(myszy_i).data_zlowienia := start_date + TRUNC(DBMS_RANDOM.VALUE(0, next_date - start_date));
        IF myszy_table(myszy_i).data_zlowienia > sroda THEN
          myszy_table(myszy_i).data_wydania := next_sroda;
        ELSE
          myszy_table(myszy_i).data_wydania := sroda;
        END IF;
        myszy_i := myszy_i + 1;
        myszy_danego_kota := myszy_danego_kota + 1;
      END LOOP;
    END LOOP;

    i := kocury_i;
    do_wydania := 0;

    -- Wydawanie myszy
    WHILE myszy_i_previous < myszy_i
    LOOP
      IF do_wydania = 0 AND i > 1 THEN
        i := i - 1;
        do_wydania := NVL(kocury_table(i).przydzial_myszy, 0) + NVL(kocury_table(i).myszy_extra, 0);
      END IF;
      myszy_table(myszy_i_previous).zjadacz := kocury_table(i).pseudo;
      do_wydania := do_wydania - 1;
      myszy_i_previous := myszy_i_previous + 1;
    END LOOP;

    start_date := next_date;
    sroda := next_sroda;
    next_date := ADD_MONTHS(start_date, 1);
    next_sroda := NEXT_DAY(LAST_DAY(next_date) - 7, 'środa');
  END LOOP;

  next_date := end_date;
  srednia := srednia * (next_date - start_date) / 31;

  -- Wypelnianie ostatniego miesiaca do polowy, bez wydawania
  FOR i IN 1..kocury_table.COUNT
  LOOP
    myszy_danego_kota := 0;
    WHILE myszy_danego_kota < srednia
    LOOP
      myszy_table(myszy_i).nr_myszy := myszy_i;
      myszy_table(myszy_i).lowca := kocury_table(i).pseudo;
      myszy_table(myszy_i).waga_myszy := ROUND(DBMS_RANDOM.VALUE(15, 35), 2);
      myszy_table(myszy_i).data_zlowienia := start_date + TRUNC(DBMS_RANDOM.VALUE(0, next_date - start_date));
      myszy_i := myszy_i + 1;
      myszy_danego_kota := myszy_danego_kota + 1;
    END LOOP;
  END LOOP;

  -- Wprowadzanie danych do tabeli
  FORALL i IN 1..myszy_table.COUNT SAVE EXCEPTIONS
  INSERT INTO Myszy VALUES (
    myszy_table(i).nr_myszy,
    myszy_table(i).lowca,
    myszy_table(i).zjadacz,
    myszy_table(i).waga_myszy,
    myszy_table(i).data_zlowienia,
    myszy_table(i).data_wydania
  );

EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;

/

BEGIN
  FOR kot IN (SELECT pseudo FROM Kocury)
  LOOP
   EXECUTE IMMEDIATE 'CREATE TABLE Myszy_' || kot.pseudo || ' (
    nr_myszy NUMBER CONSTRAINT m_nm_' || kot.pseudo || '_pk PRIMARY KEY,
    waga_myszy NUMBER CONSTRAINT m_wm_' || kot.pseudo || '_nn NOT NULL
                      CONSTRAINT m_wm_' || kot.pseudo || '_ch CHECK(waga_myszy BETWEEN 15 AND 35),
    data_zlowienia DATE CONSTRAINT m_dz_' || kot.pseudo || '_nn NOT NULL
  )';
  END LOOP;
END;

/

INSERT ALL
  INTO Myszy_TYGRYS VALUES(1,20,'2021-01-26')
  INTO Myszy_TYGRYS VALUES(2,25,'2021-01-26')
  INTO Myszy_TYGRYS VALUES(3,30,'2021-01-26')
SELECT * FROM Dual;

/

CREATE OR REPLACE PROCEDURE Przyjmij_mysz(pseudonim Kocury.pseudo % TYPE, dzien DATE)
AS
  i NUMBER;
  nr NUMBER;
  brak_kota EXCEPTION;

  TYPE nowe_myszy_type IS TABLE OF Myszy_TYGRYS % ROWTYPE INDEX BY BINARY_INTEGER;
  nowe_myszy_table nowe_myszy_type;

  TYPE do_wprowadzenia_type IS TABLE OF Myszy % ROWTYPE INDEX BY BINARY_INTEGER;
  do_wprowadzenia_table do_wprowadzenia_type;
BEGIN
  SELECT COUNT(pseudo) INTO i
  FROM Kocury
  WHERE pseudo = pseudonim;

  IF i <> 1 THEN
    RAISE brak_kota;
  END IF;

  SELECT MAX(nr_myszy) + 1 INTO nr
  FROM Myszy;

  EXECUTE IMMEDIATE '
    SELECT nr_myszy, waga_myszy, data_zlowienia
    FROM Myszy_' || pseudonim || '
    WHERE data_zlowienia = ''' || dzien || ''''
  BULK COLLECT INTO nowe_myszy_table;

  FOR i IN 1..nowe_myszy_table.COUNT
  LOOP
    do_wprowadzenia_table(i).nr_myszy := nr;
    do_wprowadzenia_table(i).lowca := pseudonim;
    do_wprowadzenia_table(i).waga_myszy := nowe_myszy_table(i).waga_myszy;
    do_wprowadzenia_table(i).data_zlowienia := nowe_myszy_table(i).data_zlowienia;
    nr := nr + 1;
  END LOOP;

  FORALL i IN 1..do_wprowadzenia_table.COUNT SAVE EXCEPTIONS
  INSERT INTO Myszy VALUES (
    do_wprowadzenia_table(i).nr_myszy,
    do_wprowadzenia_table(i).lowca,
    do_wprowadzenia_table(i).zjadacz,
    do_wprowadzenia_table(i).waga_myszy,
    do_wprowadzenia_table(i).data_zlowienia,
    do_wprowadzenia_table(i).data_wydania
  );

  EXECUTE IMMEDIATE 'DELETE FROM Myszy_' || pseudonim || 'WHERE data_zlowienia = ''' || dzien || '''';
EXCEPTION
  WHEN brak_kota THEN DBMS_OUTPUT.PUT_LINE('Kot o podanym pseudonimie nie istnieje');
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;

/

CREATE OR REPLACE PROCEDURE Wyplac
AS
  i NUMBER;
  sroda DATE := NEXT_DAY(LAST_DAY(SYSDATE) - 7, 'środa');
  do_przydzielenia NUMBER := 0;
  kocury_i NUMBER := 1;
  wprowadzono BOOLEAN;

  TYPE do_wydania_type IS TABLE OF Myszy % ROWTYPE INDEX BY BINARY_INTEGER;
  do_wydania_table do_wydania_type;

  TYPE kocury_record_type IS RECORD (pseudo Kocury.pseudo % TYPE, spozycie NUMBER(3));
  TYPE kocury_table_type IS TABLE OF kocury_record_type INDEX BY BINARY_INTEGER;
  kocury_table kocury_table_type;
BEGIN
  SELECT * BULK COLLECT INTO do_wydania_table
  FROM Myszy
  WHERE zjadacz IS NULL;

  SELECT pseudo, NVL(przydzial_myszy, 0) + NVL(myszy_extra, 0) BULK COLLECT INTO kocury_table
  FROM Kocury
  WHERE w_stadku_od <= LAST_DAY(ADD_MONTHS(SYSDATE, -1))
  CONNECT BY PRIOR pseudo = szef
  START WITH szef IS NULL
  ORDER BY LEVEL;

  FOR i IN 1..kocury_table.COUNT
  LOOP
    do_przydzielenia := do_przydzielenia + kocury_table(i).spozycie;
  END LOOP;


  FOR i IN 1..do_wydania_table.COUNT
  LOOP
    EXIT WHEN i > do_przydzielenia;
    wprowadzono := FALSE;

    WHILE NOT wprowadzono
    LOOP
      IF kocury_i > kocury_table.COUNT THEN
        kocury_i := 1;
      END IF;
      IF kocury_table(kocury_i).spozycie > 0 THEN
        do_wydania_table(i).zjadacz := kocury_table(kocury_i).pseudo;
        do_wydania_table(i).data_wydania := sroda;
        kocury_table(kocury_i).spozycie := kocury_table(kocury_i).spozycie - 1;
        wprowadzono := TRUE;
      END IF;
      kocury_i := kocury_i + 1;
    END LOOP;
  END LOOP;

  FORALL i IN 1..do_wydania_table.COUNT SAVE EXCEPTIONS
  UPDATE Myszy
    SET zjadacz = do_wydania_table(i).zjadacz,
        data_wydania = do_wydania_table(i).data_wydania
    WHERE nr_myszy = do_wydania_table(i).nr_myszy;
EXCEPTION
  WHEN OTHERS THEN DBMS_OUTPUT.PUT_LINE(SQLERRM);
END;

/

DROP PROCEDURE Przyjmij_mysz;
DROP PROCEDURE Wyplac;
BEGIN
  FOR kot IN (SELECT pseudo FROM Kocury)
  LOOP
    EXECUTE IMMEDIATE 'DROP TABLE Myszy_' || kot.pseudo;
  END LOOP;
END;
DROP TABLE Myszy;

-- zlicznie ilości myszy na koncie dla kotów płci M, którzy mają incydenty.
SELECT K.wlasciciel.kot.pseudo, COUNT(nr_wpisu)
FROM KontaO K
WHERE K.wlasciciel.kot.plec = 'M'
      AND data_usuniecia IS NULL
      AND EXISTS(SELECT * FROM IncydentyO I WHERE I.kot.pseudo = K.wlasciciel.kot.pseudo)
GROUP BY K.wlasciciel.kot.pseudo;
