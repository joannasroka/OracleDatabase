-- zad 34
DECLARE
    liczba_kotow    INTEGER;
    szukana_funkcja VARCHAR2(50) := :funkcja;
BEGIN
    SELECT COUNT(*)
    INTO liczba_kotow
    FROM KOCURY
    WHERE FUNKCJA = szukana_funkcja;
    IF liczba_kotow > 0 THEN
        DBMS_OUTPUT.PUT_LINE('Znaleziono koty o funkcji: ' || szukana_funkcja);
    ELSE
        DBMS_OUTPUT.PUT_LINE('Nie znaleziono.');
    END IF;
END;

-- zad 35
DECLARE
    imie_kota           KOCURY.IMIE%TYPE;
    przydzial_roczny    NUMBER;
    miesiac_przyst      NUMBER;
    odpowiada_kryteriom BOOLEAN := FALSE;
BEGIN
    SELECT IMIE,
           (NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0)) * 12,
           EXTRACT(MONTH FROM W_STADKU_OD)
    INTO imie_kota, przydzial_roczny, miesiac_przyst
    FROM KOCURY
    WHERE PSEUDO = :pseudo;
    IF przydzial_roczny > 700
    THEN
        odpowiada_kryteriom := TRUE;
        DBMS_OUTPUT.PUT_LINE('calkowity roczny przydzial myszy >700');
    END IF;
    IF imie_kota LIKE '%A%'
    THEN
        odpowiada_kryteriom := TRUE;
        DBMS_OUTPUT.PUT_LINE('imie zawiera litere A');
    END IF;
    IF miesiac_przyst = 5
    THEN
        odpowiada_kryteriom := TRUE;
        DBMS_OUTPUT.PUT_LINE('maj jest miesiacem przystapienia do stadka');
    END IF;
    IF NOT odpowiada_kryteriom
    THEN
        DBMS_OUTPUT.PUT_LINE('nie odpowiada kryteriom');
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('nie znaleziono kota o podanym pseudo');
END;

-- zad 36

DECLARE
    CURSOR do_podwyzki IS
        SELECT PSEUDO,
               NVL(PRZYDZIAL_MYSZY, 0) ZJADA,
               F.MAX_MYSZY             MAX
        FROM KOCURY
                 JOIN FUNKCJE F ON KOCURY.FUNKCJA = F.FUNKCJA
        ORDER BY "ZJADA"
            FOR UPDATE OF PRZYDZIAL_MYSZY;
    suma_przedzialow NUMBER := 0;
    ile_zmian        NUMBER := 0;
    kot              do_podwyzki%ROWTYPE;
BEGIN
    SELECT SUM(NVL(PRZYDZIAL_MYSZY, 0)) INTO suma_przedzialow FROM KOCURY;
    OPEN do_podwyzki;
    WHILE suma_przedzialow <= 1050
        LOOP
            FETCH do_podwyzki INTO kot;

            IF do_podwyzki%NOTFOUND THEN
                CLOSE do_podwyzki;
                OPEN do_podwyzki;
                FETCH do_podwyzki INTO kot;
            END IF;

            IF ROUND(kot.ZJADA * 1.1) <= kot.MAX THEN
                suma_przedzialow := suma_przedzialow + ROUND(kot.ZJADA * 0.1);
                ile_zmian := ile_zmian + 1;
                UPDATE KOCURY
                SET PRZYDZIAL_MYSZY = ROUND(PRZYDZIAL_MYSZY * 1.1)
                WHERE CURRENT OF do_podwyzki;
            ELSIF kot.ZJADA <> kot.MAX THEN
                suma_przedzialow := suma_przedzialow + kot.MAX - kot.ZJADA;
                ile_zmian := ile_zmian + 1;
                UPDATE KOCURY
                SET PRZYDZIAL_MYSZY = kot.MAX
                WHERE CURRENT OF do_podwyzki;
            END IF;

        END LOOP;
    DBMS_OUTPUT.PUT_LINE(
                'Calk. przydzial w stadku - ' || TO_CHAR(suma_przedzialow) || ' Zmian - ' || TO_CHAR(ile_zmian));
    CLOSE do_podwyzki;
END ;

SELECT IMIE, PRZYDZIAL_MYSZY
FROM KOCURY;

ROLLBACK;

-- zad 37
DECLARE
    licznik NUMBER := 1;
BEGIN
    DBMS_OUTPUT.PUT_LINE('NR  PSEUDONIM  ZJADA');
    DBMS_OUTPUT.PUT_LINE('--------------------');
    FOR kot IN (SELECT PSEUDO, NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0) ZJADA FROM KOCURY ORDER BY ZJADA DESC)
        LOOP
            IF licznik > 5 THEN
                EXIT;
            END IF;
            DBMS_OUTPUT.PUT_LINE(licznik || '   ' || RPAD(kot.PSEUDO, 10) || ' ' || kot.ZJADA);
            licznik := licznik + 1;
        END LOOP;
END;

-- zad 38
DECLARE
    liczba_przelozonych     NUMBER := :liczba_przelozonych;
    max_liczba_przelozonych NUMBER;
    szerokosc_kol           NUMBER := 15;
    pseudo_aktualny         KOCURY.PSEUDO%TYPE;
    imie_aktualny           KOCURY.IMIE%TYPE;
    pseudo_nastepny         KOCURY.SZEF%TYPE;
    CURSOR podwladni IS SELECT PSEUDO, IMIE
                        FROM KOCURY
                        WHERE FUNKCJA IN ('MILUSIA', 'KOT');
BEGIN
    SELECT MAX(LEVEL) - 1
    INTO max_liczba_przelozonych
    FROM Kocury
    CONNECT BY PRIOR szef = pseudo
    START WITH funkcja IN ('KOT', 'MILUSIA');
    liczba_przelozonych := LEAST(max_liczba_przelozonych, liczba_przelozonych);

    DBMS_OUTPUT.PUT(RPAD('IMIE ', szerokosc_kol));
    FOR licznik IN 1..liczba_przelozonych
        LOOP
            DBMS_OUTPUT.PUT(RPAD('|  SZEF ' || licznik, szerokosc_kol));
        END LOOP;
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE(RPAD('-', szerokosc_kol * (liczba_przelozonych + 1), '-'));

    FOR kot IN podwladni
        LOOP
            DBMS_OUTPUT.PUT(RPAD(KOT.IMIE, szerokosc_kol));
            SELECT SZEF INTO pseudo_nastepny FROM KOCURY WHERE PSEUDO = kot.PSEUDO;
            FOR COUNTER IN 1..liczba_przelozonych
                LOOP
                    IF pseudo_nastepny IS NULL THEN
                        DBMS_OUTPUT.PUT(RPAD('|  ', szerokosc_kol));

                    ELSE
                        SELECT K.IMIE, K.PSEUDO, K.SZEF
                        INTO imie_aktualny, pseudo_aktualny, pseudo_nastepny
                        FROM KOCURY K
                        WHERE K.PSEUDO = pseudo_nastepny;
                        DBMS_OUTPUT.PUT(RPAD('|  ' || imie_aktualny, szerokosc_kol));
                    END IF;
                END LOOP;
            DBMS_OUTPUT.PUT_LINE('');
        END LOOP;
END;

-- zad 39
DECLARE
    nr_ban           KOCURY.NR_BANDY%TYPE := :nr_bandy;
    naz_ban          BANDY.NAZWA%TYPE     := :nazwa_bandy;
    ter_pol          BANDY.TEREN%TYPE     := :teren_polowan;
    ile_znalezionych NUMBER;
    juz_istnieje_exc EXCEPTION;
    zly_numer_bandy_exc EXCEPTION;
    wiadomosc_exc    VARCHAR2(30)         := '';

BEGIN
    IF nr_ban <= 0 THEN
        RAISE zly_numer_bandy_exc;
    END IF;

    SELECT COUNT(*) INTO ile_znalezionych FROM BANDY WHERE NR_BANDY = nr_ban;
    IF ile_znalezionych <> 0 THEN
        wiadomosc_exc := wiadomosc_exc || ' ' || nr_ban || ',';
    END IF;

    SELECT COUNT(*) INTO ile_znalezionych FROM BANDY WHERE NAZWA = naz_ban;
    IF ile_znalezionych <> 0 THEN
        wiadomosc_exc := wiadomosc_exc || ' ' || naz_ban || ',';
    END IF;

    SELECT COUNT(*) INTO ile_znalezionych FROM BANDY WHERE TEREN = ter_pol;
    IF ile_znalezionych <> 0 THEN
        wiadomosc_exc := wiadomosc_exc || ' ' || ter_pol || ',';
    END IF;

    IF LENGTH(wiadomosc_exc) > 0 THEN
        RAISE juz_istnieje_exc;
    END IF;

    INSERT INTO BANDY(NR_BANDY, NAZWA, TEREN) VALUES (nr_ban, naz_ban, ter_pol);
EXCEPTION
    WHEN zly_numer_bandy_exc THEN
        DBMS_OUTPUT.PUT_LINE('Nr bandy musi byc liczba dodatnia');
    WHEN juz_istnieje_exc THEN
        DBMS_OUTPUT.PUT_LINE(TRIM(TRAILING ',' FROM wiadomosc_exc) || ': juz istnieje');
END;

SELECT *
FROM BANDY;

ROLLBACK;

-- zad 40 i zad 44

CREATE OR REPLACE PACKAGE PACK IS
    FUNCTION oblicz_podatek(pseudo_k KOCURY.PSEUDO%TYPE) RETURN NUMBER;
    PROCEDURE wstaw_bande(nr_ban BANDY.NR_BANDY%TYPE, naz_ban BANDY.NAZWA%TYPE, ter_pol BANDY.TEREN%TYPE);
END PACK;

CREATE OR REPLACE PACKAGE BODY PACK IS
    FUNCTION oblicz_podatek(pseudo_k KOCURY.PSEUDO%TYPE) RETURN NUMBER
        IS
        podatek NUMBER DEFAULT 0;
        ile     NUMBER DEFAULT 0;
    BEGIN
        SELECT CEIL(0.05 * (PRZYDZIAL_MYSZY + NVL(MYSZY_EXTRA, 0))) INTO podatek FROM KOCURY WHERE PSEUDO = PSEUDO_K;
        SELECT COUNT(*) INTO ile FROM KOCURY WHERE SZEF = PSEUDO_K;
        IF ile = 0 THEN
            podatek := podatek + 2;
        END IF;
        SELECT COUNT(*) INTO ile FROM WROGOWIE_KOCUROW WHERE PSEUDO = PSEUDO_K;
        IF ile = 0 THEN
            podatek := podatek + 1;
        END IF;
        SELECT NVL(MYSZY_EXTRA, 0) INTO ile FROM KOCURY WHERE PSEUDO = PSEUDO_K;
        IF ile > 0 THEN
            podatek := podatek + 1;
        END IF;
        RETURN podatek;
    END;

    PROCEDURE wstaw_bande(nr_ban BANDY.NR_BANDY%TYPE, naz_ban BANDY.NAZWA%TYPE, ter_pol BANDY.TEREN%TYPE)
        IS
        ile_znalezionych NUMBER;
        juz_istnieje_exc EXCEPTION;
        zly_numer_bandy_exc EXCEPTION;
        wiadomosc_exc VARCHAR2(30) := '';
    BEGIN
        IF nr_ban <= 0 THEN
            RAISE zly_numer_bandy_exc;
        END IF;

        SELECT COUNT(*) INTO ile_znalezionych FROM BANDY WHERE NR_BANDY = nr_ban;
        IF ile_znalezionych <> 0 THEN
            wiadomosc_exc := wiadomosc_exc || ' ' || nr_ban || ',';
        END IF;

        SELECT COUNT(*) INTO ile_znalezionych FROM BANDY WHERE NAZWA = naz_ban;
        IF ile_znalezionych <> 0 THEN
            wiadomosc_exc := wiadomosc_exc || ' ' || naz_ban || ',';
        END IF;

        SELECT COUNT(*) INTO ile_znalezionych FROM BANDY WHERE TEREN = ter_pol;
        IF ile_znalezionych <> 0 THEN
            wiadomosc_exc := wiadomosc_exc || ' ' || ter_pol || ',';
        END IF;

        IF LENGTH(wiadomosc_exc) > 0 THEN
            RAISE juz_istnieje_exc;
        END IF;

        INSERT INTO BANDY(NR_BANDY, NAZWA, TEREN) VALUES (nr_ban, naz_ban, ter_pol);
    EXCEPTION
        WHEN zly_numer_bandy_exc THEN
            DBMS_OUTPUT.PUT_LINE('Nr bandy musi byc liczba dodatnia');
        WHEN juz_istnieje_exc THEN
            DBMS_OUTPUT.PUT_LINE(TRIM(TRAILING ',' FROM wiadomosc_exc) || ': juz istnieje');
    END;
END PACK;

BEGIN
    PACK.wstaw_bande(1, 'PUSZYSCI', 'POLE');
    PACK.wstaw_bande(10, 'PUSZYSCI', 'OGRODEK');
    FOR kot IN (SELECT pseudo FROM Kocury)
        LOOP
            DBMS_OUTPUT.PUT_LINE(RPAD(kot.pseudo, 10) || ' -> ' || PACK.oblicz_podatek(kot.pseudo));
        END LOOP;
END;

SELECT *
FROM bandy;

ROLLBACK;

DROP PACKAGE PACK;

-- zad 41

CREATE OR REPLACE TRIGGER trg_wstaw_bande
    BEFORE INSERT
    ON BANDY
    FOR EACH ROW
DECLARE
    ostatni_nr BANDY.NR_BANDY%TYPE;
BEGIN
    SELECT MAX(NR_BANDY)
    INTO ostatni_nr
    FROM BANDY;
    IF ostatni_nr + 1 <> :NEW.NR_BANDY THEN
        :NEW.NR_BANDY := ostatni_nr + 1;
    END IF;
END;

BEGIN
    wstaw_bande(1, 'PUSZYSCI', 'POLE');
    wstaw_bande(10, 'PUSZYSCI', 'OGRODEK');
END;

SELECT *
FROM BANDY;

ROLLBACK;
DROP TRIGGER trg_wstaw_bande;

-- zad 42
-- 1. rozwiazanie -> kilka wyzwalaczy + pakiet

CREATE OR REPLACE PACKAGE wirus IS
    kara NUMBER := 0;
    nagroda NUMBER := 0;
    przydzial_tygrysa NUMBER;
END;

CREATE OR REPLACE TRIGGER trg_wirus_before_update
    BEFORE UPDATE OF PRZYDZIAL_MYSZY
    ON KOCURY
DECLARE
BEGIN
    SELECT PRZYDZIAL_MYSZY INTO wirus.przydzial_tygrysa FROM KOCURY WHERE PSEUDO = 'TYGRYS';
END;

CREATE OR REPLACE TRIGGER trg_wirus_before_update_row
    BEFORE UPDATE OF PRZYDZIAL_MYSZY
    ON KOCURY
    FOR EACH ROW
DECLARE
BEGIN
    IF :NEW.FUNKCJA = 'MILUSIA' THEN
        IF :NEW.PRZYDZIAL_MYSZY <= :OLD.PRZYDZIAL_MYSZY THEN
            DBMS_OUTPUT.PUT_LINE('brak zmiany');
            :NEW.PRZYDZIAL_MYSZY := :OLD.PRZYDZIAL_MYSZY;
        ELSIF :NEW.PRZYDZIAL_MYSZY - :OLD.PRZYDZIAL_MYSZY < 0.1 * wirus.przydzial_tygrysa THEN
            DBMS_OUTPUT.PUT_LINE('podwyzka mniejsza niz 10% Tygrysa');
            :NEW.PRZYDZIAL_MYSZY := :NEW.PRZYDZIAL_MYSZY + ROUND(0.1 * wirus.przydzial_tygrysa);
            :NEW.MYSZY_EXTRA := NVL(:NEW.MYSZY_EXTRA, 0) + 5;
            wirus.kara := wirus.kara + ROUND(0.1 * wirus.przydzial_tygrysa);
        ELSE
            wirus.nagroda := wirus.nagroda + 5;
        END IF;
    END IF;
END;

CREATE OR REPLACE TRIGGER trg_wirus_after_update
    AFTER UPDATE OF PRZYDZIAL_MYSZY
    ON KOCURY
DECLARE
    przydzial KOCURY.PRZYDZIAL_MYSZY%TYPE;
    ekstra    KOCURY.MYSZY_EXTRA%TYPE;
BEGIN
    SELECT PRZYDZIAL_MYSZY, MYSZY_EXTRA
    INTO przydzial, ekstra
    FROM KOCURY K
    WHERE K.PSEUDO = 'TYGRYS';

    przydzial := przydzial - wirus.kara;
    ekstra := ekstra + wirus.nagroda;

    IF wirus.kara <> 0 OR wirus.nagroda <> 0 THEN
        wirus.kara := 0;
        wirus.nagroda := 0;
        UPDATE KOCURY
        SET PRZYDZIAL_MYSZY = przydzial,
            MYSZY_EXTRA     = ekstra
        WHERE PSEUDO = 'TYGRYS';
    END IF;
END;

UPDATE KOCURY
SET PRZYDZIAL_MYSZY = 50
WHERE PSEUDO = 'PUSZYSTA';

UPDATE Kocury
SET przydzial_myszy = przydzial_myszy + 1
WHERE funkcja = 'MILUSIA';

UPDATE Kocury
SET przydzial_myszy = przydzial_myszy + 20
WHERE funkcja = 'MILUSIA';

SELECT *
FROM KOCURY
WHERE PSEUDO IN ('PUSZYSTA', 'TYGRYS');

ROLLBACK;

DROP TRIGGER TRG_WIRUS_AFTER_UPDATE;
DROP TRIGGER TRG_WIRUS_BEFORE_UPDATE;
DROP TRIGGER TRG_WIRUS_BEFORE_UPDATE_ROW;
DROP PACKAGE WIRUS;

-- 2. rozwiazanie -> wyzwalacz COMPOUND

CREATE OR REPLACE TRIGGER trg_wirus_compound
    FOR UPDATE OF PRZYDZIAL_MYSZY
    ON KOCURY
    COMPOUND TRIGGER
    przydzial_tygrysa KOCURY.PRZYDZIAL_MYSZY%TYPE;
    ekstra KOCURY.MYSZY_EXTRA%TYPE;
    kara NUMBER := 0;
    nagroda NUMBER := 0;

BEFORE STATEMENT IS
BEGIN
    SELECT PRZYDZIAL_MYSZY INTO przydzial_tygrysa FROM KOCURY WHERE PSEUDO = 'TYGRYS';
END BEFORE STATEMENT;

    BEFORE EACH ROW IS
    BEGIN
        IF :NEW.FUNKCJA = 'MILUSIA' THEN
            IF :NEW.PRZYDZIAL_MYSZY <= :OLD.PRZYDZIAL_MYSZY THEN
                DBMS_OUTPUT.PUT_LINE('brak zmiany');
                :NEW.PRZYDZIAL_MYSZY := :OLD.PRZYDZIAL_MYSZY;
            ELSIF :NEW.PRZYDZIAL_MYSZY - :OLD.PRZYDZIAL_MYSZY < 0.1 * przydzial_tygrysa THEN
                DBMS_OUTPUT.PUT_LINE('podwyzka mniejsza niz 10% Tygrysa');
                :NEW.PRZYDZIAL_MYSZY := :NEW.PRZYDZIAL_MYSZY + ROUND(0.1 * przydzial_tygrysa);
                :NEW.MYSZY_EXTRA := NVL(:NEW.MYSZY_EXTRA, 0) + 5;
                kara := kara + ROUND(0.1 * przydzial_tygrysa);
            ELSE
                nagroda := nagroda + 5;
            END IF;
        END IF;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
    BEGIN
        SELECT MYSZY_EXTRA
        INTO ekstra
        FROM KOCURY
        WHERE PSEUDO = 'TYGRYS';

        przydzial_tygrysa := przydzial_tygrysa - kara;
        ekstra := ekstra + nagroda;

        IF kara <> 0 OR nagroda <> 0 THEN
            DBMS_OUTPUT.PUT_LINE('Nowy przydzial Tygrysa: ' || przydzial_tygrysa);
            DBMS_OUTPUT.PUT_LINE('Nowe myszy ekstra Tygrysa: ' || ekstra);
            kara := 0;
            nagroda := 0;
            UPDATE KOCURY
            SET PRZYDZIAL_MYSZY = przydzial_tygrysa,
                MYSZY_EXTRA     = ekstra
            WHERE PSEUDO = 'TYGRYS';
        END IF;
    END AFTER STATEMENT;
    END;

UPDATE KOCURY
SET PRZYDZIAL_MYSZY = 50
WHERE PSEUDO = 'PUSZYSTA';

UPDATE Kocury
SET przydzial_myszy = przydzial_myszy + 1
WHERE funkcja = 'MILUSIA';

UPDATE Kocury
SET przydzial_myszy = przydzial_myszy + 20
WHERE funkcja = 'MILUSIA';

SELECT *
FROM KOCURY
WHERE PSEUDO IN ('PUSZYSTA', 'TYGRYS');

ROLLBACK;
DROP TRIGGER trg_wirus_compound;

-- zad 43

DECLARE
    CURSOR funkcje IS (SELECT funkcja
                       FROM FUNKCJE
                       WHERE funkcja <> 'HONOROWA');
    CURSOR iloscKotow IS SELECT COUNT(*) ilosc, SUM(NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0)) sumaMyszy
                         FROM Kocury,
                              Bandy
                         WHERE Kocury.nr_bandy = Bandy.nr_bandy
                         GROUP BY Bandy.nazwa, Kocury.plec
                         ORDER BY Bandy.nazwa, plec;
    CURSOR funkcjezBand IS SELECT SUM(NVL(Kocury.PRZYDZIAL_MYSZY, 0) + NVL(Kocury.MYSZY_EXTRA, 0)) sumaMyszy,
                                  Kocury.Funkcja                                                   funkcja,
                                  Bandy.nazwa                                                      naz,
                                  Kocury.plec                                                      pl
                           FROM Kocury,
                                Bandy
                           WHERE Kocury.nr_bandy = Bandy.nr_bandy
                           GROUP BY Bandy.nazwa, Kocury.plec, Kocury.funkcja
                           ORDER BY Bandy.nazwa, Kocury.plec, Kocury.funkcja;
    ilosc NUMBER;
    il    iloscKotow%ROWTYPE;
    bpf   funkcjezBand%ROWTYPE;
BEGIN
    DBMS_OUTPUT.put('NAZWA BANDY       PLEC    ILE ');
    FOR fun IN funkcje
        LOOP
            DBMS_OUTPUT.put(RPAD(fun.funkcja, 10));
        END LOOP;

    DBMS_OUTPUT.put_line('    SUMA');
    DBMS_OUTPUT.put('---------------- ------ ----');

    FOR fun IN funkcje
        LOOP
            DBMS_OUTPUT.put(' ---------');
        END LOOP;
    DBMS_OUTPUT.put_line(' --------');


    OPEN iloscKotow;
    OPEN funkcjezBand;
    FETCH funkcjezBand INTO bpf;
    FOR banda IN (SELECT nazwa, NR_BANDY FROM BANDY WHERE nazwa <> 'ROCKERSI' ORDER BY nazwa)
        LOOP

            FOR ple IN (SELECT PLEC FROM KOCURY GROUP BY PLEC ORDER BY PLEC )
                LOOP
                    DBMS_OUTPUT.put(CASE WHEN ple.plec = 'M' THEN RPAD(' ', 18) ELSE RPAD(banda.nazwa, 18) END);
                    DBMS_OUTPUT.put(CASE WHEN ple.plec = 'M' THEN 'Kocor' ELSE 'Kotka' END);

                    FETCH iloscKotow INTO il;
                    DBMS_OUTPUT.put(LPAD(il.ilosc, 4));
                    FOR fun IN funkcje
                        LOOP
                            IF fun.funkcja = bpf.funkcja AND banda.nazwa = bpf.naz AND ple.plec = bpf.pl
                            THEN
                                DBMS_OUTPUT.put(LPAD(NVL(bpf.sumaMyszy, 0), 10));
                                FETCH funkcjezBand INTO bpf;
                            ELSE
                                DBMS_OUTPUT.put(LPAD(NVL(0, 0), 10));

                            END IF;
                        END LOOP;

                    DBMS_OUTPUT.put(LPAD(NVL(il.sumaMyszy, 0), 10));
                    DBMS_OUTPUT.new_line();
                END LOOP;

        END LOOP;
    CLOSE iloscKotow;
    CLOSE funkcjezBand;
    DBMS_OUTPUT.put('Z---------------- ------ ----');
    FOR fun IN funkcje
        LOOP
            DBMS_OUTPUT.put(' ---------');
        END LOOP;
    DBMS_OUTPUT.put_line(' --------');

    DBMS_OUTPUT.put('Zjada razem                ');
    FOR fun IN funkcje
        LOOP
            SELECT SUM(NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0))
            INTO ilosc
            FROM Kocury K
            WHERE K.FUNKCJA = fun.FUNKCJA;
            DBMS_OUTPUT.put(LPAD(NVL(ilosc, 0), 10));
        END LOOP;

    SELECT SUM(nvl(PRZYDZIAL_MYSZY, 0) + nvl(MYSZY_EXTRA, 0)) INTO ilosc FROM Kocury;
    DBMS_OUTPUT.put(LPAD(ilosc, 10));
    DBMS_OUTPUT.new_line();
END;


-- zad 45

CREATE TABLE DODATKI_EXTRA
(
    PSEUDO    VARCHAR2(15) NOT NULL,
    DOD_EXTRA NUMBER(3) DEFAULT 0
);

CREATE OR REPLACE TRIGGER trg_tygrys_update
    BEFORE UPDATE OF PRZYDZIAL_MYSZY
    ON KOCURY
    FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    IF LOGIN_USER <> 'TYGRYS' AND :NEW.PRZYDZIAL_MYSZY > :OLD.PRZYDZIAL_MYSZY AND :NEW.FUNKCJA = 'MILUSIA' THEN
        EXECUTE IMMEDIATE
            'DECLARE
                ILE NUMBER;
                DOD NUMBER;
                CURSOR milusie IS SELECT PSEUDO
                FROM KOCURY
                WHERE funkcja = ''MILUSIA'';
            BEGIN
            FOR milusia IN milusie
                LOOP
                SELECT COUNT(*) INTO ILE FROM DODATKI_EXTRA WHERE PSEUDO = milusia.PSEUDO;
                IF ILE = 0 THEN
                    INSERT INTO DODATKI_EXTRA(PSEUDO, DOD_EXTRA) VALUES(milusia.PSEUDO, -10);
                    ELSE
                        SELECT DOD_EXTRA INTO DOD FROM DODATKI_EXTRA WHERE PSEUDO = milusia.PSEUDO;
                        UPDATE DODATKI_EXTRA SET DOD_EXTRA = DOD - 10 WHERE PSEUDO = milusia.PSEUDO;
                    END IF;
                END LOOP;
            END;';

        COMMIT;
    END IF;
END;

UPDATE KOCURY
SET PRZYDZIAL_MYSZY = 100
WHERE IMIE = 'SONIA';

UPDATE KOCURY
SET PRZYDZIAL_MYSZY = 200
WHERE IMIE = 'SONIA';

SELECT *
FROM KOCURY
WHERE FUNKCJA = 'MILUSIA';

ROLLBACK;

DROP TABLE DODATKI_EXTRA;
DROP TRIGGER trg_tygrys_update;

-- zad 46
CREATE TABLE WYKROCZENIA
(
    KTO      VARCHAR2(15) NOT NULL,
    KIEDY    DATE         NOT NULL,
    KOMU     VARCHAR2(15) NOT NULL,
    OPERACJA VARCHAR2(15) NOT NULL
);

CREATE OR REPLACE TRIGGER trg_sprawdz_przydzial
    BEFORE INSERT OR UPDATE OF PRZYDZIAL_MYSZY
    ON KOCURY
    FOR EACH ROW
DECLARE
    MIN_M     FUNKCJE.MIN_MYSZY%TYPE;
    MAX_M     FUNKCJE.MAX_MYSZY%TYPE;
    POZA_WIDELKAMI EXCEPTION;
    CURR_DATE DATE DEFAULT SYSDATE;
    EVENT     VARCHAR2(20);
    PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    SELECT MIN_MYSZY, MAX_MYSZY INTO MIN_M, MAX_M FROM FUNKCJE WHERE FUNKCJA = :NEW.FUNKCJA;
    IF MAX_M < :NEW.PRZYDZIAL_MYSZY OR :NEW.PRZYDZIAL_MYSZY < MIN_M THEN
        IF INSERTING THEN
            EVENT := 'INSERT';
        ELSIF UPDATING THEN
            EVENT := 'UPDATE';
        END IF;
        INSERT INTO WYKROCZENIA(KTO, KIEDY, KOMU, OPERACJA) VALUES (ORA_LOGIN_USER, CURR_DATE, :NEW.PSEUDO, EVENT);
        COMMIT;
        RAISE POZA_WIDELKAMI;
    END IF;
EXCEPTION
    WHEN POZA_WIDELKAMI THEN
        DBMS_OUTPUT.PUT_LINE('poza widelkami');
END;

UPDATE KOCURY
SET PRZYDZIAL_MYSZY = 80
WHERE IMIE = 'JACEK';
ROLLBACK;

DROP TABLE WYKROCZENIA;
DROP TRIGGER trg_sprawdz_przydzial;