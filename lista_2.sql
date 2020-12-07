ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';

-- zad 17

SELECT PSEUDO "POLUJE W POLU", NVL(PRZYDZIAL_MYSZY, 0) "PRZYDZIAL MYSZY", NAZWA "BANDA"
FROM KOCURY K,
     BANDY B
WHERE K.NR_BANDY = B.NR_BANDY
  AND NVL(PRZYDZIAL_MYSZY, 0) > 50
  AND TEREN IN ('CALOSC', 'POLE')
ORDER BY "PRZYDZIAL_MYSZY" DESC;

SELECT PSEUDO "POLUJE W POLU", NVL(PRZYDZIAL_MYSZY, 0) "PRZYDZIAL MYSZY", NAZWA "BANDA"
FROM KOCURY K
         JOIN BANDY B ON K.NR_BANDY = B.NR_BANDY
WHERE NVL(PRZYDZIAL_MYSZY, 0) > 50
  AND TEREN IN ('CALOSC', 'POLE')
ORDER BY "PRZYDZIAL_MYSZY" DESC;

-- zad 18

SELECT K1.IMIE, K1.W_STADKU_OD "POLUJE OD"
FROM KOCURY K1
         JOIN KOCURY K2 ON K2.IMIE = 'JACEK'
WHERE K1.W_STADKU_OD < K2.W_STADKU_OD
ORDER BY K1.W_STADKU_OD DESC;

-- zad 19
-- a) z wykorzystaniem tylko złączeń
SELECT K1.IMIE,
       K1.FUNKCJA,
       NVL(K2.IMIE, ' ') "Szef 1",
       NVL(K3.IMIE, ' ') "Szef 2",
       NVL(K4.IMIE, ' ') "Szef 3"
FROM KOCURY K1
         LEFT JOIN KOCURY K2 ON K1.SZEf = K2.PSEUDO
         LEFT JOIN KOCURY K3 ON K2.SZEF = K3.PSEUDO
         LEFT JOIN KOCURY K4 ON K3.SZEF = K4.PSEUDO
WHERE K1.FUNKCJA IN ('KOT', 'MILUSIA');

-- b) z wykorzystaniem drzewa, operatora CONNECT_BY_ROOT i tabel przestawnych
-- CONNECT_BY_ROOT zwraca Imie i funkcje korzenia, czyli tego od ktorego sie zaczelo
SELECT *
FROM (SELECT IMIE, level "Poziom", CONNECT_BY_ROOT IMIE "Imie", CONNECT_BY_ROOT FUNKCJA "Funkcja"
      FROM KOCURY
      CONNECT BY PRIOR SZEF = PSEUDO
      START WITH FUNKCJA IN ('KOT', 'MILUSIA'))
    PIVOT (
    MAX(IMIE)
    FOR "Poziom"
    IN (2 "Szef 1",3 "Szef 2",4 "Szef 3")
    );

-- c) z wykorzystaniem drzewa i funkcji SYS_CONNECT_BY_PATH i operatora CONNECT_BY_ROOT
-- SYS_CONNECT_BY_PATH pokazuje droge od korzenia do aktualnego
SELECT CONNECT_BY_ROOT IMIE    "Imie",
       CONNECT_BY_ROOT FUNKCJA "Funkcja",
       SUBSTR(SYS_CONNECT_BY_PATH(IMIE, ' | '), LENGTH(CONNECT_BY_ROOT IMIE) + 5)
                               "Imiona kolejnych szefow"
FROM KOCURY
WHERE SZEF IS NULL
CONNECT BY PRIOR SZEF = PSEUDO
START WITH FUNKCJA IN ('KOT', 'MILUSIA');

-- zad 20
SELECT IMIE             "Imie kotki",
       NAZWA            "Nazwa bandy",
       WK.IMIE_WROGA    "Imie wroga",
       STOPIEN_WROGOSCI "Ocena wroga",
       DATA_INCYDENTU   "Data inc."
FROM KOCURY K
         JOIN BANDY B ON K.NR_BANDY = B.NR_BANDY
         JOIN WROGOWIE_KOCUROW WK ON K.PSEUDO = WK.PSEUDO
         JOIN WROGOWIE W ON WK.IMIE_WROGA = W.IMIE_WROGA
WHERE PLEC = 'D'
  AND DATA_INCYDENTU > '2007-01-01';

-- zad 21
SELECT NAZWA "Nazwa bandy", COUNT(DISTINCT WK.PSEUDO) "Koty z wrogami"
FROM BANDY B
         JOIN KOCURY K on B.NR_BANDY = K.NR_BANDY
         JOIN WROGOWIE_KOCUROW WK on K.PSEUDO = WK.PSEUDO
GROUP BY B.NAZWA;

-- zad 22
-- CZEMU trzeba tez grupowac wedlug funkcji?
SELECT FUNKCJA "Funkcja", K.PSEUDO "Pseudonim kota", COUNT(K.PSEUDO) "Liczba wrogow"
FROM KOCURY K
         JOIN WROGOWIE_KOCUROW WK on K.PSEUDO = WK.PSEUDO
GROUP BY K.PSEUDO, FUNKCJA
HAVING COUNT(K.PSEUDO) > 1;

-- zad 23
SELECT IMIE, (NVL(PRZYDZIAL_MYSZY, 0) + MYSZY_EXTRA) * 12 "DAWKA ROCZNA", 'ponizej 864' "DAWKA"
FROM KOCURY
WHERE NVL(MYSZY_EXTRA, 0) > 0
  AND (NVL(PRZYDZIAL_MYSZY, 0) + MYSZY_EXTRA) * 12 < 864
UNION ALL
SELECT IMIE, (NVL(PRZYDZIAL_MYSZY, 0) + MYSZY_EXTRA) * 12 "DAWKA ROCZNA", '864' "DAWKA"
FROM KOCURY
WHERE NVL(MYSZY_EXTRA, 0) > 0
  AND (NVL(PRZYDZIAL_MYSZY, 0) + MYSZY_EXTRA) * 12 = 864
UNION ALL
SELECT IMIE, (NVL(PRZYDZIAL_MYSZY, 0) + MYSZY_EXTRA) * 12 "DAWKA ROCZNA", 'powyzej 864' "DAWKA"
FROM KOCURY
WHERE NVL(MYSZY_EXTRA, 0) > 0
  AND (NVL(PRZYDZIAL_MYSZY, 0) + MYSZY_EXTRA) * 12 > 864
ORDER BY "DAWKA ROCZNA" DESC;

-- zad 24
-- 1. sposob - bez podzapytan i operatorow zbiorowych
SELECT B.NR_BANDY, NAZWA, TEREN
FROM BANDY B
         LEFT JOIN KOCURY K on B.NR_BANDY = K.NR_BANDY
WHERE K.NR_BANDY IS NULL;

-- 2. sposob - wykorzystujac operatory zbiorowe (UNION, INTERSECT, MINUS)
SELECT B.NR_BANDY, NAZWA, TEREN
FROM BANDY B
MINUS
SELECT B.NR_BANDY, NAZWA, TEREN
FROM BANDY B
         JOIN KOCURY K on B.NR_BANDY = K.NR_BANDY;

-- zad 25
SELECT IMIE, FUNKCJA, NVL(PRZYDZIAL_MYSZY, 0)
FROM KOCURY
WHERE NVL(PRZYDZIAL_MYSZY, 0) >= ALL (
    SELECT NVL(PRZYDZIAL_MYSZY, 0) * 3
    FROM KOCURY K
             JOIN BANDY B on K.NR_BANDY = B.NR_BANDY
    WHERE FUNKCJA = 'MILUSIA'
      AND TEREN IN ('SAD', 'CALOSC'));

-- zad 26
SELECT FUNKCJA,
       ROUND(AVG(NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0))) "Srednio najw. i najm. myszy"
FROM KOCURY
WHERE FUNKCJA != 'SZEFUNIO'
GROUP BY FUNKCJA
HAVING AVG(NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0))
           IN
       ((SELECT MAX(AVG(NVL(PRZYDZIAL_MYSZY
                            , 0) + NVL(MYSZY_EXTRA
                            , 0))) "Max przydzial"
         FROM KOCURY
         WHERE FUNKCJA != 'SZEFUNIO'
         GROUP BY FUNKCJA),
        (SELECT MIN(AVG(NVL(PRZYDZIAL_MYSZY
                            , 0) + NVL(MYSZY_EXTRA
                            , 0))) "Min przydzial"
         FROM KOCURY
         WHERE FUNKCJA != 'SZEFUNIO'
         GROUP BY FUNKCJA)
           );

-- zad 27
-- a) wykorzystując podzapytanie skorelowane
-- Czyli dla Tygrysa jest 0 kotów lepszych, dla Lysego jest jeden kot lepszy, czyli Tygrys
SELECT K.PSEUDO, NVL(K.PRZYDZIAL_MYSZY, 0) + NVL(K.MYSZY_EXTRA, 0) "ZJADA"
FROM KOCURY K
WHERE (SELECT COUNT(DISTINCT NVL(K2.PRZYDZIAL_MYSZY, 0) + NVL(K2.MYSZY_EXTRA, 0))
       FROM KOCURY K2
       WHERE NVL(K2.PRZYDZIAL_MYSZY, 0) + NVL(K2.MYSZY_EXTRA, 0) > NVL(K.PRZYDZIAL_MYSZY, 0) + NVL(K.MYSZY_EXTRA, 0))
          < :liczba_miejsc
ORDER BY "ZJADA" DESC;

-- b) wykorzystując pseudokolumnę ROWNUM
SELECT PSEUDO, NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0) "ZJADA"
FROM KOCURY
WHERE NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0)
          IN (SELECT "ZJADA"
              FROM (SELECT DISTINCT NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0) "ZJADA"
                    FROM KOCURY
                    ORDER BY "ZJADA" DESC)
              WHERE ROWNUM <= :liczba_miejsc);

-- c) wykorzystując złączenie relacji Kocury z relacją Kocury
SELECT K1.PSEUDO, NVL(K1.PRZYDZIAL_MYSZY, 0) + NVL(K1.MYSZY_EXTRA, 0) "ZJADA"
FROM KOCURY K1
         JOIN KOCURY K2 ON NVL(K1.PRZYDZIAL_MYSZY, 0) + NVL(K1.MYSZY_EXTRA, 0) <=
                           NVL(K2.PRZYDZIAL_MYSZY, 0) + NVL(K2.MYSZY_EXTRA, 0)
GROUP BY K1.PSEUDO, NVL(K1.PRZYDZIAL_MYSZY, 0) + NVL(K1.MYSZY_EXTRA, 0)
HAVING COUNT(DISTINCT NVL(K2.PRZYDZIAL_MYSZY, 0) + NVL(K2.MYSZY_EXTRA, 0)) <= :liczba_miejsc
ORDER BY "ZJADA" DESC;

-- d) wykorzystując funkcje analityczne.
SELECT PSEUDO, "ZJADA"
FROM (SELECT PSEUDO,
             NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0)                                   "ZJADA",
             DENSE_RANK() OVER (ORDER BY NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0) DESC) "Ranking"
      FROM KOCURY)
WHERE "Ranking" <= :liczba_miejsc;


-- zad 28
SELECT TO_CHAR(EXTRACT(YEAR FROM W_STADKU_OD)) "ROK", COUNT(*) "LICZBA WSTAPIEN"
FROM KOCURY
GROUP BY EXTRACT(YEAR FROM W_STADKU_OD)
HAVING COUNT(*) IN (
                    (SELECT MAX(COUNT(*)) "LICZBA WSTAPIEN"
                     FROM KOCURY
                     GROUP BY EXTRACT(YEAR FROM W_STADKU_OD)
                     HAVING COUNT(*)
                                < (SELECT AVG(COUNT(*))
                                   FROM KOCURY
                                   GROUP BY EXTRACT(YEAR FROM W_STADKU_OD))), (SELECT MIN(COUNT(*)) "LICZBA WSTAPIEN"
                                                                               FROM KOCURY
                                                                               GROUP BY EXTRACT(YEAR FROM W_STADKU_OD)
                                                                               HAVING COUNT(*)
                                                                                          > (SELECT AVG(COUNT(*))
                                                                                             FROM KOCURY
                                                                                             GROUP BY EXTRACT(YEAR FROM W_STADKU_OD))))
UNION ALL
SELECT 'Srednia', AVG(COUNT(*)) "LICZBA WSTAPIEN"
FROM KOCURY
GROUP BY EXTRACT(YEAR FROM W_STADKU_OD)
ORDER BY 2;

-- zad 29
-- a) ze złączeniem ale bez podzapytań
-- tutaj dla kazdego imienia mamy kazdy z kazdym ale join po nr bandy, wiec dla kazdego kota mamy wszystkie koty z jego bandy
SELECT K1.IMIE,
       NVL(K1.PRZYDZIAL_MYSZY, 0) + NVL(K1.MYSZY_EXTRA, 0)      "ZJADA",
       K1.NR_BANDY,
       AVG(NVL(K2.PRZYDZIAL_MYSZY, 0) + NVL(K2.MYSZY_EXTRA, 0)) "Srednia bandy"
FROM KOCURY K1
         JOIN KOCURY K2 ON K1.NR_BANDY = K2.NR_BANDY
WHERE K1.PLEC = 'M'
GROUP BY K1.IMIE, K1.NR_BANDY, NVL(K1.PRZYDZIAL_MYSZY, 0) + NVL(K1.MYSZY_EXTRA, 0)
HAVING NVL(K1.PRZYDZIAL_MYSZY, 0) + NVL(K1.MYSZY_EXTRA, 0) <= AVG(NVL(K2.PRZYDZIAL_MYSZY, 0) + NVL(K2.MYSZY_EXTRA, 0));

-- b) ze złączeniem i z jedynym podzapytaniem w klauzurze FROM
SELECT IMIE, NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0) "ZJADA", K.NR_BANDY, "Srednia bandy"
FROM KOCURY K
         JOIN (SELECT NR_BANDY, AVG(NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0)) "Srednia bandy"
               FROM KOCURY
               GROUP BY NR_BANDY) SR
              ON K.NR_BANDY = SR.NR_BANDY
WHERE K.PLEC = 'M'
  AND NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0) <= SR."Srednia bandy";

-- c) bez złączeń i z dwoma podzapytaniami: w klauzurach SELECT i WHERE
SELECT IMIE,
       NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0) "ZJADA",
       NR_BANDY,
       (SELECT AVG(NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0))
        FROM KOCURY
        WHERE NR_BANDY = K.NR_BANDY)                 "Srednia bandy"
FROM KOCURY K
WHERE PLEC = 'M'
  AND NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0) < (SELECT AVG(NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0))
                                                       FROM KOCURY
                                                       WHERE NR_BANDY = K.NR_BANDY);

-- zad 30
SELECT IMIE, W_STADKU_OD || ' <--- NAJSTARSZY STAZEM W BANDZIE ' || NAZWA "WSTAPIL DO STADKA"
FROM KOCURY K1
         JOIN (SELECT K2.NR_BANDY, NAZWA, MIN(K2.W_STADKU_OD) Najstarszy
               FROM KOCURY K2
                        JOIN BANDY ON K2.NR_BANDY = BANDY.NR_BANDY
               GROUP BY K2.NR_BANDY, NAZWA) STARY ON K1.NR_BANDY = STARY.NR_BANDY
WHERE W_STADKU_OD = STARY.Najstarszy
UNION ALL
SELECT IMIE, W_STADKU_OD || ' <--- NAJMLODSZY STAZEM W BANDZIE ' || NAZWA "WSTAPIL DO STADKA"
FROM KOCURY K1
         JOIN (SELECT K2.NR_BANDY, NAZWA, MAX(K2.W_STADKU_OD) Najmlodszy
               FROM KOCURY K2
                        JOIN BANDY ON K2.NR_BANDY = BANDY.NR_BANDY
               GROUP BY K2.NR_BANDY, NAZWA) MLODY ON K1.NR_BANDY = MLODY.NR_BANDY
WHERE W_STADKU_OD = MLODY.Najmlodszy
UNION ALL
SELECT IMIE, W_STADKU_OD || ' ' "WSTAPIL DO STADKA"
FROM KOCURY K1
         JOIN (SELECT K2.NR_BANDY, NAZWA, MIN(K2.W_STADKU_OD) Najstarszy
               FROM KOCURY K2
                        JOIN BANDY ON K2.NR_BANDY = BANDY.NR_BANDY
               GROUP BY K2.NR_BANDY, NAZWA) STARY ON K1.NR_BANDY = STARY.NR_BANDY
         JOIN (SELECT K2.NR_BANDY, NAZWA, MAX(K2.W_STADKU_OD) Najmlodszy
               FROM KOCURY K2
                        JOIN BANDY ON K2.NR_BANDY = BANDY.NR_BANDY
               GROUP BY K2.NR_BANDY, NAZWA) MLODY ON K1.NR_BANDY = MLODY.NR_BANDY
WHERE W_STADKU_OD != STARY.Najstarszy AND W_STADKU_OD != MLODY.Najmlodszy
ORDER BY IMIE;

-- Zad 31
CREATE OR REPLACE VIEW perspektywa_band(nazwa_bandy, sre_spoz, max_spoz, min_spoz, koty, koty_z_dod)
AS
SELECT nazwa,
       AVG(NVL(przydzial_myszy, 0)),
       MAX(NVL(przydzial_myszy, 0)),
       MIN(NVL(przydzial_myszy, 0)),
       COUNT(pseudo),
       COUNT(myszy_extra)
FROM Bandy B
         JOIN Kocury K ON B.nr_bandy = K.nr_bandy
GROUP BY nazwa;

SELECT *
FROM perspektywa_band;

SELECT pseudo                                  "PSEUDONIM",
       imie,
       funkcja,
       NVL(przydzial_myszy, 0)                 "ZJADA",
       'OD ' || min_spoz || ' DO ' || max_spoz "GRANICE SPOZYCIA",
       w_stadku_od                             "LOWI_OD"
FROM Kocury K
         JOIN Bandy B ON K.nr_bandy = B.nr_bandy
         JOIN perspektywa_band pb ON B.nazwa = pb.nazwa_bandy
WHERE pseudo = :pseudonim;

DROP VIEW perspektywa_band;

-- Zad 32
SELECT PSEUDO, NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0) "ZJADA"
FROM KOCURY
WHERE NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0)
          IN (SELECT "ZJADA"
              FROM (SELECT DISTINCT NVL(PRZYDZIAL_MYSZY, 0) + NVL(MYSZY_EXTRA, 0) "ZJADA"
                    FROM KOCURY
                    ORDER BY "ZJADA" DESC)
              WHERE ROWNUM <= :liczba_miejsc);


CREATE OR REPLACE VIEW do_podwyzki(pseudo, plec, przydzial_myszy, myszy_extra, nr_bandy)
AS
SELECT PSEUDO, PLEC, PRZYDZIAL_MYSZY, MYSZY_EXTRA, NR_BANDY
FROM KOCURY
WHERE PSEUDO IN (
    SELECT PSEUDO
    FROM (
             SELECT pseudo, W_STADKU_OD
             FROM Kocury K
                      JOIN Bandy B ON K.nr_bandy = B.nr_bandy
             WHERE nazwa = 'CZARNI RYCERZE'
             ORDER BY W_STADKU_OD
         )
    WHERE ROWNUM <= 3
)
   OR PSEUDO IN (
    SELECT PSEUDO
    FROM (
             SELECT pseudo, W_STADKU_OD
             FROM Kocury K
                      JOIN Bandy B ON K.nr_bandy = B.nr_bandy
             WHERE nazwa = 'LACIACI MYSLIWI'
             ORDER BY W_STADKU_OD
         )
    WHERE ROWNUM <= 3
);

SELECT pseudo                  "PSEUDONIM",
       plec,
       NVL(przydzial_myszy, 0) "Myszy przed podw.",
       NVL(myszy_extra, 0)     "Extra przed podw."
FROM do_podwyzki;

UPDATE do_podwyzki
SET przydzial_myszy = przydzial_myszy + DECODE(plec, 'M', 10,
                                               0.1 * (SELECT MIN(przydzial_myszy) FROM Kocury)),

    myszy_extra     = NVL(myszy_extra, 0) + 0.15 * (
        SELECT AVG(NVL(myszy_extra, 0))
        FROM Kocury K
        WHERE nr_bandy = do_podwyzki.nr_bandy
    );

SELECT pseudo                  "PSEUDONIM",
       plec,
       NVL(przydzial_myszy, 0) "Myszy przed podw.",
       NVL(myszy_extra, 0)     "Extra przed podw."
FROM do_podwyzki;

DROP VIEW do_podwyzki;
ROLLBACK;