--
-- PostgreSQL database dump
--

\restrict WQXuK37zJM5cZeO44LcU1gVCvKQRXOzUgSRKX1zIW8f181mnBzIZG0aZZIrmGxH

-- Dumped from database version 14.1
-- Dumped by pg_dump version 15.14

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO postgres;

--
-- Name: unaccent; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;


--
-- Name: EXTENSION unaccent; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION unaccent IS 'text search dictionary that removes accents';


--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


--
-- Name: f_audit_knihy(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.f_audit_knihy() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Pokud se změní název nebo počet stran
    IF OLD.title <> NEW.title OR OLD.pages <> NEW.pages THEN
        INSERT INTO audit_log (book_id, old_title, new_title, changed_by)
        VALUES (OLD.book_id, OLD.title, NEW.title, current_user);
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.f_audit_knihy() OWNER TO postgres;

--
-- Name: f_pocet_stran_autora(character varying); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.f_pocet_stran_autora(jmeno_autora character varying) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
    celkem_stran BIGINT;
BEGIN
    SELECT SUM(b.pages) INTO celkem_stran
    FROM books b
    JOIN books_authors ba ON b.book_id = ba.book_id
    JOIN authors a ON ba.author_id = a.author_id
    WHERE a.name = jmeno_autora;

    RETURN COALESCE(celkem_stran, 0);
END;
$$;


ALTER FUNCTION public.f_pocet_stran_autora(jmeno_autora character varying) OWNER TO postgres;

--
-- Name: p_analyzovat_narocnost(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.p_analyzovat_narocnost()
    LANGUAGE plpgsql
    AS $$
DECLARE
    cur_books CURSOR FOR
        SELECT title, pages FROM books;

    v_title varchar(100);
    v_pages smallint;
    v_kategorie varchar(50);
    v_cas numeric;
BEGIN
    CREATE TABLE IF NOT EXISTS analyza_cteni (
        id SERIAL PRIMARY KEY,
        nazev_knihy varchar(255),
        kategorie_narocnosti varchar(50),
        odhad_casu_hodiny numeric(4,1),
        zpracovano_kdy timestamp DEFAULT now()
    );
    DELETE FROM analyza_cteni;

    OPEN cur_books;

    LOOP
        FETCH cur_books INTO v_title, v_pages;
        EXIT WHEN NOT FOUND;

        IF v_pages > 5000 THEN
            RAISE NOTICE 'Nalezena podezřelá kniha "%" s % stranami. RUŠÍM VŠECHNY ZMĚNY!', v_title, v_pages;
            ROLLBACK;
            RETURN;
        END IF;
        BEGIN
            IF v_pages IS NULL THEN
                RAISE EXCEPTION 'Počet stran je neznámý (NULL)';
            END IF;

            IF v_pages < 200 THEN
                v_kategorie := 'Jednohubka';
            ELSIF v_pages BETWEEN 200 AND 500 THEN
                v_kategorie := 'Klasický román';
            ELSE
                v_kategorie := 'Bichle';
            END IF;

            v_cas := round(v_pages / 30.0, 1);

            INSERT INTO analyza_cteni (nazev_knihy, kategorie_narocnosti, odhad_casu_hodiny)
            VALUES (v_title, v_kategorie, v_cas);

        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Varování: Přeskakuji knihu "%": %', v_title, SQLERRM;
        END;
    END LOOP;

    CLOSE cur_books;
    COMMIT;
    RAISE NOTICE 'Analýza úspěšně dokončena a uložena.';
END;
$$;


ALTER PROCEDURE public.p_analyzovat_narocnost() OWNER TO postgres;

--
-- Name: p_analyzovat_narocnost_transakce(); Type: PROCEDURE; Schema: public; Owner: postgres
--

CREATE PROCEDURE public.p_analyzovat_narocnost_transakce()
    LANGUAGE plpgsql
    AS $$
DECLARE
    cur_books CURSOR FOR
        SELECT title, pages FROM books;

    v_title varchar(100);
    v_pages smallint;
    v_kategorie varchar(50);
    v_cas numeric;
BEGIN
    CREATE TABLE IF NOT EXISTS analyza_cteni (
        id SERIAL PRIMARY KEY,
        nazev_knihy varchar(255),
        kategorie_narocnosti varchar(50),
        odhad_casu_hodiny numeric(4,1),
        zpracovano_kdy timestamp DEFAULT now()
    );
    DELETE FROM analyza_cteni;

    OPEN cur_books;

    LOOP
        FETCH cur_books INTO v_title, v_pages;
        EXIT WHEN NOT FOUND;

        IF v_pages > 5000 THEN
            RAISE NOTICE 'Nalezena podezřelá kniha "%" s % stranami. RUŠÍM VŠECHNY ZMĚNY!', v_title, v_pages;
            ROLLBACK;
            RETURN;
        END IF;
        BEGIN
            IF v_pages IS NULL THEN
                RAISE EXCEPTION 'Počet stran je neznámý (NULL)';
            END IF;

            IF v_pages < 200 THEN
                v_kategorie := 'Jednohubka';
            ELSIF v_pages BETWEEN 200 AND 500 THEN
                v_kategorie := 'Klasický román';
            ELSE
                v_kategorie := 'Bichle';
            END IF;

            v_cas := round(v_pages / 30.0, 1);

            INSERT INTO analyza_cteni (nazev_knihy, kategorie_narocnosti, odhad_casu_hodiny)
            VALUES (v_title, v_kategorie, v_cas);

        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE 'Varování: Přeskakuji knihu "%": %', v_title, SQLERRM;
        END;
    END LOOP;

    CLOSE cur_books;
    COMMIT;
    RAISE NOTICE 'Analýza úspěšně dokončena a uložena.';
END;
$$;


ALTER PROCEDURE public.p_analyzovat_narocnost_transakce() OWNER TO postgres;

--
-- Name: cs_search; Type: TEXT SEARCH CONFIGURATION; Schema: public; Owner: postgres
--

CREATE TEXT SEARCH CONFIGURATION public.cs_search (
    PARSER = pg_catalog."default" );

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR asciiword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR word WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR numword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR email WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR url WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR host WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR sfloat WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR version WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR hword_numpart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR hword_part WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR hword_asciipart WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR numhword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR asciihword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR hword WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR url_path WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR file WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR "float" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR "int" WITH simple;

ALTER TEXT SEARCH CONFIGURATION public.cs_search
    ADD MAPPING FOR uint WITH simple;


ALTER TEXT SEARCH CONFIGURATION public.cs_search OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.audit_log (
    id integer NOT NULL,
    book_id uuid,
    old_title character varying,
    new_title character varying,
    changed_by character varying,
    changed_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.audit_log OWNER TO postgres;

--
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.audit_log_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.audit_log_id_seq OWNER TO postgres;

--
-- Name: audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.audit_log_id_seq OWNED BY public.audit_log.id;


--
-- Name: authors; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.authors (
    author_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(64) NOT NULL,
    birthdate date,
    country_id uuid,
    biography text
);


ALTER TABLE public.authors OWNER TO postgres;

--
-- Name: book_formats; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.book_formats (
    book_format_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(32) NOT NULL
);


ALTER TABLE public.book_formats OWNER TO postgres;

--
-- Name: books; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.books (
    book_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    title character varying(100) NOT NULL,
    isbn character varying(13),
    pages smallint,
    description text,
    publisher_id uuid,
    language_id uuid NOT NULL,
    format_id uuid NOT NULL,
    publication_year smallint,
    previous_book_id uuid
);


ALTER TABLE public.books OWNER TO postgres;

--
-- Name: books_authors; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.books_authors (
    book_id uuid NOT NULL,
    author_id uuid NOT NULL
);


ALTER TABLE public.books_authors OWNER TO postgres;

--
-- Name: languages; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.languages (
    language_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(32) NOT NULL
);


ALTER TABLE public.languages OWNER TO postgres;

--
-- Name: publishers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.publishers (
    publisher_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(100) NOT NULL,
    founded date,
    country_id uuid
);


ALTER TABLE public.publishers OWNER TO postgres;

--
-- Name: books_full_view; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.books_full_view AS
 SELECT books.book_id,
    books.title,
    books.isbn,
    books.publication_year,
    books.description,
    books.pages,
    authors.name AS author_name,
    authors.birthdate,
    authors.biography,
    languages.name AS language,
    book_formats.name AS book_format,
    COALESCE(publishers.name, authors.name) AS publisher
   FROM (((((public.books
     JOIN public.books_authors ON ((books_authors.book_id = books.book_id)))
     JOIN public.authors ON ((authors.author_id = books_authors.author_id)))
     JOIN public.languages ON ((books.language_id = languages.language_id)))
     JOIN public.book_formats ON ((books.format_id = book_formats.book_format_id)))
     LEFT JOIN public.publishers ON ((books.publisher_id = publishers.publisher_id)));


ALTER TABLE public.books_full_view OWNER TO postgres;

--
-- Name: books_genres; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.books_genres (
    book_id uuid NOT NULL,
    genre_id uuid NOT NULL
);


ALTER TABLE public.books_genres OWNER TO postgres;

--
-- Name: countries; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.countries (
    country_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(64) NOT NULL
);


ALTER TABLE public.countries OWNER TO postgres;

--
-- Name: genres; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.genres (
    genre_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name character varying(32) NOT NULL
);


ALTER TABLE public.genres OWNER TO postgres;

--
-- Name: audit_log id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_log ALTER COLUMN id SET DEFAULT nextval('public.audit_log_id_seq'::regclass);


--
-- Data for Name: audit_log; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.audit_log (id, book_id, old_title, new_title, changed_by, changed_at) FROM stdin;
1	4d729925-0c74-4c4e-b885-265652199cf5	Hvězda tajemného lesa: výprava za pokladem	Hvězda tajemného lesa: výprava za pokladem	postgres	2025-12-15 15:17:30.722077
2	4d729925-0c74-4c4e-b885-265652199cf5	Hvězda tajemného lesa: výprava za pokladem	test	postgres	2025-12-15 15:19:53.063929
\.


--
-- Data for Name: authors; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.authors (author_id, name, birthdate, country_id, biography) FROM stdin;
b9cfc8b5-b3cc-4fcd-a02f-d0ee4d5d74f9	Jan Doležal	1950-09-29	6378a4d4-390b-446d-8541-e7239fc9dc90	Jan Doležal je český autor historických románů a esejista, známý svou přesností a jazykovou vytříbeností.
adf58bcf-b547-4886-ae19-793e956310a4	Petra Novotná	1971-06-05	6378a4d4-390b-446d-8541-e7239fc9dc90	Petra Novotná se specializuje na psychologické thrillery a patří mezi nejčtenější autorky v Česku.
1be612db-952a-4d52-b087-b9aed16b980c	Luis Fernández	1961-01-07	2f210199-8f43-45e1-9817-f838dc872d21	Luis Fernández je španělský spisovatel píšící romány o lásce a životě v Andalusii.
5cb98e1b-5dc8-477a-b686-d62bff118d6d	Marie Bartošová	1991-05-22	6378a4d4-390b-446d-8541-e7239fc9dc90	Marie Bartošová je oceňovaná autorka dětských knih a ilustrátorka z Brna.
5a2e5b36-f584-4bb9-846f-94ea7813a067	Giulia Rossi	1980-08-19	567e11ce-a010-411f-8509-acb65d049ce7	Giulia Rossi je italská autorka současné literatury a profesorka literární vědy.
5f8ecd9f-4baf-4a3f-8f21-ccdedf509bc0	Thomas Berger	1973-12-12	0f1249ec-f650-4ac5-932a-7a6d05b4819e	Thomas Berger je německý romanopisec zaměřený na témata identity a společnosti.
616d6a4a-0650-4681-89b7-30ff5bcd1625	Isabelle Lefèvre	1955-04-28	be697431-f394-46c7-b017-63b803fd9073	Isabelle Lefèvre píše poetické romány o pařížském životě a mezilidských vztazích.
58f1ea7d-6e35-4eb3-9651-455a5436adfa	Carlos Méndez	1979-01-16	6e5b7f20-9b8e-412d-a740-14e528989144	Carlos Méndez je mexický novinář a autor dokumentárních reportáží o latinskoamerické kultuře.
84c66dbe-414e-47af-993a-1d09a7d5127a	Lucía Ortega	1956-07-12	00be0e3a-c92c-4696-9686-d503ef4f3548	Lucía Ortega je argentinská autorka magického realismu, inspirovaná rodným venkovem.
c65759af-9004-4902-a09e-0f557d6bcb0e	Mateo Rojas	1965-11-18	b2881310-e2ff-4496-818c-d3cb99902cc1	Mateo Rojas je paraguayský spisovatel zabývající se postkoloniální historií a kulturou.
2c4be0f2-acb0-4f68-9ae1-3faf5487a38a	Jakub Beneš	1978-12-21	6378a4d4-390b-446d-8541-e7239fc9dc90	Jakub Beneš se věnuje populárně-naučné literatuře o moderních technologiích.
3b759b76-0492-4324-85c2-bef40aa3e8cd	Franjo Petrovic	1976-07-29	feb4429f-77ff-47c8-9fe6-d17fed8d949b	Franjo Petrovic je chorvatský autor válečných románů a bývalý válečný zpravodaj.
a251fde2-ec97-49fd-a062-ca3787ceb101	Elena Greco	1984-12-24	567e11ce-a010-411f-8509-acb65d049ce7	Elena Greco je italská spisovatelka zaměřená na historické romány z renesanční Florencie.
1e26b603-c6a2-4eae-a358-59c022824045	Jean Moreau	1954-09-04	be697431-f394-46c7-b017-63b803fd9073	Jean Moreau píše filozofické eseje a je pravidelným přispěvatelem literárních časopisů.
de66b26c-f7ec-4101-80d3-30623e5696ea	Hans Weber	1976-04-03	0f1249ec-f650-4ac5-932a-7a6d05b4819e	Hans Weber je německý autor detektivek odehrávajících se v Berlíně.
2732dd76-e1cc-4873-842d-2464deefff8a	Veronika Králová	1970-06-09	6378a4d4-390b-446d-8541-e7239fc9dc90	Veronika Králová je česká autorka romantické beletrie pro mladé ženy.
9e3bcc96-b512-40ed-a9de-5fa3c3d5c874	Pablo Álvarez	1972-06-05	00be0e3a-c92c-4696-9686-d503ef4f3548	Pablo Álvarez píše o společenských změnách v Latinské Americe.
8d8cde2a-b4cc-4eeb-8e5c-2365cdf5bfab	Eva Štěpánková	1964-05-27	6378a4d4-390b-446d-8541-e7239fc9dc90	Eva Štěpánková je česká dramatička a autorka divadelních her.
a8225590-021e-4000-b902-6de2f8ccccb3	María del Carmen López	1971-12-28	6e5b7f20-9b8e-412d-a740-14e528989144	María del Carmen López je mexická spisovatelka zaměřující se na životní příběhy žen z venkova.
0834dcd7-f466-44de-9402-cf413dd1c10d	Agnieszka Kowalska	1989-05-25	f28d0468-49cc-414f-bd92-efb4d34ff912	Agnieszka Kowalska je polská básnířka a autorka esejů o ženách v literatuře.
\.


--
-- Data for Name: book_formats; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.book_formats (book_format_id, name) FROM stdin;
773a6553-7226-4bc6-9296-28258a88d014	Pevná vazba
ca47b3f2-57f9-42e5-930a-9fb788d82d3a	Brožovaná vazba
1673c35b-09eb-4b71-a156-1d217749f634	E-kniha
5267a797-d212-4d5a-8c2f-4f741f783a7d	Audiokniha
\.


--
-- Data for Name: books; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.books (book_id, title, isbn, pages, description, publisher_id, language_id, format_id, publication_year, previous_book_id) FROM stdin;
9e25bff8-c7de-453e-871e-8fec4d35fb72	Zámek ztraceného času: pátrání po tajemství	9780273825692	222	Napínavý příběh cestovateli, kde hlavní roli hrají odvaha a přátelství.	2ad5dd3f-b2f9-4683-a9f4-3e974747cde5	f36a910d-d774-4f0b-865d-4a4e739ce42e	773a6553-7226-4bc6-9296-28258a88d014	2006	\N
84eabd33-3275-4fd5-8524-818fbadc029b	Příběh opuštěné vesnice: hledání pravdy	9781405250054	705	Příběh o vědci, který čelí osudu v starém hradě.	\N	f36a910d-d774-4f0b-865d-4a4e739ce42e	5267a797-d212-4d5a-8c2f-4f741f783a7d	2015	\N
4d729925-0c74-4c4e-b885-265652199cf5	test	9781522888291	999	Historický pohled na rodinné tragédie, který změnil v budoucnosti.	7f973681-a90e-4e2d-8ddd-220909838dd4	f36a910d-d774-4f0b-865d-4a4e739ce42e	773a6553-7226-4bc6-9296-28258a88d014	2003	\N
6ec83c86-13db-4e6a-9715-22ded9b251d0	Řeka ztraceného času: hledání pravdy	9781092668736	172	Napínavý příběh vědci, kde hlavní roli hrají odvaha a přátelství.	fe698774-81f9-4114-990b-6c85849d5151	f36a910d-d774-4f0b-865d-4a4e739ce42e	773a6553-7226-4bc6-9296-28258a88d014	2008	\N
613d9939-a729-409b-b904-4b183f9219eb	Dům pouště naděje: dobrodružství v divočině	9781436944373	403	Dobrodružství mladém muži během dlouhé cesty, plné dojemných momentů.	d7f4b28a-b3a2-49ca-8b66-659cf5987b08	9bba6c9e-d917-472e-9fb3-f7486f98a742	773a6553-7226-4bc6-9296-28258a88d014	2002	\N
e3a0bec9-c5df-46fc-a34f-fcb4900b0cfc	Město starého hradu: hledání pravdy	9781395886394	517	Příběh o lékařce, který čelí osudu v během války.	d4f93c0f-14bf-4c3e-9e94-877ca23288f5	cf810987-bde2-4332-a18f-a461db6be827	773a6553-7226-4bc6-9296-28258a88d014	2008	\N
436e4d09-2319-423c-96d0-e5b7df8cd9d0	Legenda zázračného pramene: útěk před osudem	9781374908741	990	Příběh o statečné dívce, který prožívá nečekaná dobrodružství v během války.	\N	800ae597-dcdf-48e6-85e4-2c62458431da	773a6553-7226-4bc6-9296-28258a88d014	2007	\N
8a1fa577-2243-4db6-88c2-5d1a70664ec0	Královna temné věže: cesta za snem	9780880659635	479	Napínavý příběh cestovateli, kde hlavní roli hrají vnitřní síla.	26015f35-3313-4109-8861-f50dbf59b12d	800ae597-dcdf-48e6-85e4-2c62458431da	5267a797-d212-4d5a-8c2f-4f741f783a7d	2015	\N
2bfa3a98-12f3-4e77-94c0-83041d44106c	Město zázračného pramene: hledání pravdy	9781091786561	670	Dobrodružství statečné dívce během revoluce, plné napínavých momentů.	\N	f36a910d-d774-4f0b-865d-4a4e739ce42e	5267a797-d212-4d5a-8c2f-4f741f783a7d	2007	\N
7d98dfc2-83c8-407f-b33d-904c001ed553	Příběh ztracené zahrady: cesta za snem	9781283125710	472	Historický pohled na revoluce, který změnil během války.	c6ad42d0-3e1e-4afe-96e7-b192f9e806bb	800ae597-dcdf-48e6-85e4-2c62458431da	5267a797-d212-4d5a-8c2f-4f741f783a7d	2015	\N
90b35dde-131c-48d6-9617-2a9909949bc4	Dům opuštěné vesnice: cesta za snem	9780259357780	576	Román sleduje statečné dívce a jejich cestu skrze náročné rozhodnutí.	fe698774-81f9-4114-990b-6c85849d5151	f36a910d-d774-4f0b-865d-4a4e739ce42e	773a6553-7226-4bc6-9296-28258a88d014	2003	\N
036e5b7c-49af-4905-a5d0-05c5c5e4c6a6	Zahrada divoké řeky: pátrání po tajemství	9781180531027	362	Román sleduje statečné dívce a jejich cestu skrze náročné rozhodnutí.	26015f35-3313-4109-8861-f50dbf59b12d	9bba6c9e-d917-472e-9fb3-f7486f98a742	5267a797-d212-4d5a-8c2f-4f741f783a7d	2005	\N
1f1a8636-8f11-489e-a752-028f295208dd	Hvězda města snů: hledání pravdy	9780339748071	648	Dobrodružství mladém muži během rodinné tragédie, plné smutných momentů.	8fd3fe04-ed88-4b3f-9eff-fb207522991c	cf810987-bde2-4332-a18f-a461db6be827	773a6553-7226-4bc6-9296-28258a88d014	2006	\N
dbf9d2bf-dba4-4abd-9f8d-d7314a7c2865	Město královského paláce: dobrodružství v divočině	9780705189323	372	Příběh o starém učiteli, který prožívá nečekaná dobrodružství v starém hradě.	fe698774-81f9-4114-990b-6c85849d5151	800ae597-dcdf-48e6-85e4-2c62458431da	5267a797-d212-4d5a-8c2f-4f741f783a7d	2003	\N
b9cf660f-cec3-4eba-b1ae-12819a7accdc	Sen divoké řeky: dobrodružství v divočině	9780471597339	204	Dobrodružství statečné dívce během objevení pokladu, plné smutných momentů.	c84adfa5-977d-4f63-9cc1-bf924a75ae1a	7d0850a3-2fc4-4916-b400-7b846a51e8ad	ca47b3f2-57f9-42e5-930a-9fb788d82d3a	2008	\N
7240234f-3660-4eb7-8897-ba793a57fd07	Osud divoké řeky: putování bez cíle	9780379650525	637	Napínavý příběh lékařce, kde hlavní roli hrají touha po svobodě.	c84adfa5-977d-4f63-9cc1-bf924a75ae1a	f36a910d-d774-4f0b-865d-4a4e739ce42e	1673c35b-09eb-4b71-a156-1d217749f634	2017	\N
46953f54-de91-4812-9cad-c1c00e5b6235	Dobrodružství ledového království: pátrání po tajemství	9780113116256	994	Dobrodružství cestovateli během rodinné tragédie, plné veselých momentů.	d7f4b28a-b3a2-49ca-8b66-659cf5987b08	9bba6c9e-d917-472e-9fb3-f7486f98a742	1673c35b-09eb-4b71-a156-1d217749f634	2021	\N
2e8bc4bd-e7a3-457e-89ff-aad86911ddcc	Cesta tajemného lesa: pátrání po tajemství	9781421858067	213	Historický pohled na rodinné tragédie, který změnil Paříži.	d4f93c0f-14bf-4c3e-9e94-877ca23288f5	9bba6c9e-d917-472e-9fb3-f7486f98a742	1673c35b-09eb-4b71-a156-1d217749f634	2003	\N
9fd23eec-ddd2-4403-823a-e1f1b7590639	Bitva čarovné louky: putování bez cíle	9780812583700	665	Dobrodružství spisovatelce během dlouhé cesty, plné smutných momentů.	6af877ce-b6cd-4fbb-b276-d327bcd7ca34	7d0850a3-2fc4-4916-b400-7b846a51e8ad	1673c35b-09eb-4b71-a156-1d217749f634	2020	\N
d4ec24fe-9c99-49e9-9575-d84da76a6357	Město starého hradu: cesta za snem	9780468390516	131	Příběh o vojákovi, který bojuje za pravdu v během války.	09fe256f-313e-4250-9ffe-bb910ff64f27	f36a910d-d774-4f0b-865d-4a4e739ce42e	1673c35b-09eb-4b71-a156-1d217749f634	2021	\N
678e8a78-d323-46e8-886f-972de6e3583f	Příběh ztracené zahrady: útěk před osudem	9780968852880	156	Dobrodružství vědci během revoluce, plné dojemných momentů.	09fe256f-313e-4250-9ffe-bb910ff64f27	9bba6c9e-d917-472e-9fb3-f7486f98a742	ca47b3f2-57f9-42e5-930a-9fb788d82d3a	2023	\N
42b7b6d5-0b3f-41e0-8983-deb711b1b4fb	Dům čarovné louky: putování bez cíle	9780275225964	200	Příběh o vojákovi, který čelí osudu v Paříži.	d7f4b28a-b3a2-49ca-8b66-659cf5987b08	7d0850a3-2fc4-4916-b400-7b846a51e8ad	5267a797-d212-4d5a-8c2f-4f741f783a7d	2016	\N
15f2c5a4-d00c-450c-8eb8-5feba89e9e95	Sen ledového království: pátrání po tajemství	9780642494627	621	Napínavý příběh lékařce, kde hlavní roli hrají tajemství a odhalení.	\N	f36a910d-d774-4f0b-865d-4a4e739ce42e	ca47b3f2-57f9-42e5-930a-9fb788d82d3a	2012	\N
0d091561-a820-48a7-82a4-b7cc15e6d8c7	Zámek opuštěné vesnice: výprava za pokladem	9780878381487	687	Dobrodružství spisovatelce během objevení pokladu, plné inspirativních momentů.	09fe256f-313e-4250-9ffe-bb910ff64f27	7d0850a3-2fc4-4916-b400-7b846a51e8ad	ca47b3f2-57f9-42e5-930a-9fb788d82d3a	2023	\N
f383e8d6-893b-48f0-98ca-463cc785345f	Návrat ztracené zahrady: zápas se stíny	9781068976988	517	Román sleduje vojákovi a jejich cestu skrze válečné strasti.	c6ad42d0-3e1e-4afe-96e7-b192f9e806bb	f36a910d-d774-4f0b-865d-4a4e739ce42e	1673c35b-09eb-4b71-a156-1d217749f634	2010	\N
a5e9b3ac-50fe-43a8-92ea-5310ed2ab23a	Bitva temné věže: zápas se stíny	9780311525973	946	Román sleduje cestovateli a jejich cestu skrze velkou lásku.	a773d6cd-c91a-4861-92c7-4299712e1b95	cf810987-bde2-4332-a18f-a461db6be827	ca47b3f2-57f9-42e5-930a-9fb788d82d3a	2019	\N
95733110-2da1-4ae0-a1a3-e4160f1c191a	Zámek královského paláce: hledání pravdy	9780392753494	476	Napínavý příběh vědci, kde hlavní roli hrají tajemství a odhalení.	4f226913-73bc-45d5-811b-15d88ff5758d	cf810987-bde2-4332-a18f-a461db6be827	ca47b3f2-57f9-42e5-930a-9fb788d82d3a	2000	\N
90e2c2ba-7bfa-4363-8bab-1335ad01cc26	Vzpomínky ledového království: cesta za snem	9780646419923	325	Příběh o cestovateli, který prožívá nečekaná dobrodružství v starém hradě.	09fe256f-313e-4250-9ffe-bb910ff64f27	800ae597-dcdf-48e6-85e4-2c62458431da	5267a797-d212-4d5a-8c2f-4f741f783a7d	2013	\N
205e541a-e6ac-40ee-ab27-8ffa274d8dc0	Královna křišťálového zámku: cesta za snem	9781656212702	513	Historický pohled na rodinné tragédie, který změnil v budoucnosti.	eeff29ac-393e-4c5b-a1a6-ede64f518eff	7d0850a3-2fc4-4916-b400-7b846a51e8ad	ca47b3f2-57f9-42e5-930a-9fb788d82d3a	2008	\N
2ddf16ff-f36a-4fd8-ac2e-62b1ae3d2e72	Poutník tajemného lesa: dobrodružství v divočině	9780551539167	477	Napínavý příběh vědci, kde hlavní roli hrají touha po svobodě.	b5036804-98ef-4538-9103-11c90750d618	f36a910d-d774-4f0b-865d-4a4e739ce42e	5267a797-d212-4d5a-8c2f-4f741f783a7d	2017	\N
c6e50a2e-7cb6-4cfa-8578-c2db52c9bc2b	Dům města snů: cesta za snem	9780638190090	527	Dobrodružství statečné dívce během objevení pokladu, plné veselých momentů.	935a47b6-4fbb-4780-89dc-4e1c05eeae85	800ae597-dcdf-48e6-85e4-2c62458431da	773a6553-7226-4bc6-9296-28258a88d014	2008	613d9939-a729-409b-b904-4b183f9219eb
bcf44523-deb3-44b9-b7e6-104712de061f	Anděl divoké řeky: výprava za pokladem	9780831489342	454	Historický pohled na revoluce, který změnil v budoucnosti.	b5036804-98ef-4538-9103-11c90750d618	800ae597-dcdf-48e6-85e4-2c62458431da	773a6553-7226-4bc6-9296-28258a88d014	2017	cf129447-2e40-435b-a366-4654ac4bb38e
8499aa6d-f7cc-44ed-af37-3c08db1c7c22	Dobrodružství tajemného lesa: putování bez cíle	9781467388627	523	Román sleduje mladém muži a jejich cestu skrze válečné strasti.	d4f93c0f-14bf-4c3e-9e94-877ca23288f5	9bba6c9e-d917-472e-9fb3-f7486f98a742	5267a797-d212-4d5a-8c2f-4f741f783a7d	2016	04428484-c54e-4d7c-9b4d-641bdd06b71b
e4e5c1d7-2f2d-485f-886d-bcfefa967e84	Vzpomínky divoké řeky: návrat domů	9781237514416	492	Dobrodružství spisovatelce během rodinné tragédie, plné veselých momentů.	7f973681-a90e-4e2d-8ddd-220909838dd4	7d0850a3-2fc4-4916-b400-7b846a51e8ad	5267a797-d212-4d5a-8c2f-4f741f783a7d	2017	\N
af01a7bc-cd38-44f2-81be-73ea42fb3335	Zámek zázračného pramene: zápas se stíny	9780648619635	891	Román sleduje mladém muži a jejich cestu skrze velkou lásku.	bfc7cb0a-431f-4cb0-bcb0-59ecae451258	cf810987-bde2-4332-a18f-a461db6be827	5267a797-d212-4d5a-8c2f-4f741f783a7d	2010	\N
91ca65c2-1051-41d8-a0d2-346011d49612	Legenda ledového království: hledání pravdy	9781525813184	172	Dobrodružství statečné dívce během dlouhé cesty, plné inspirativních momentů.	935a47b6-4fbb-4780-89dc-4e1c05eeae85	cf810987-bde2-4332-a18f-a461db6be827	773a6553-7226-4bc6-9296-28258a88d014	2021	\N
bd87c205-3030-43f7-8d17-a89e66af1054	Návrat starého hradu: boj o přežití	9781420940930	319	Historický pohled na revoluce, který změnil divočině.	935a47b6-4fbb-4780-89dc-4e1c05eeae85	7d0850a3-2fc4-4916-b400-7b846a51e8ad	1673c35b-09eb-4b71-a156-1d217749f634	2010	\N
e0e5019c-ccc9-4b9a-ae31-e0b66f4ba4c6	Zahrada tajemného lesa: putování bez cíle	9781036344559	607	Román sleduje cestovateli a jejich cestu skrze náročné rozhodnutí.	2ad5dd3f-b2f9-4683-a9f4-3e974747cde5	cf810987-bde2-4332-a18f-a461db6be827	5267a797-d212-4d5a-8c2f-4f741f783a7d	2021	\N
3ec96580-5cd0-453e-a6a5-811a138956fa	Návrat opuštěné vesnice: cesta za snem	9780283272752	754	Historický pohled na revoluce, který změnil Paříži.	6af877ce-b6cd-4fbb-b276-d327bcd7ca34	7d0850a3-2fc4-4916-b400-7b846a51e8ad	5267a797-d212-4d5a-8c2f-4f741f783a7d	2023	\N
b101e2c0-5fd5-4da4-b329-fea3a62e9bd2	Dobrodružství ztraceného času: cesta za snem	9781673967265	477	Román sleduje vojákovi a jejich cestu skrze velkou lásku.	def18138-d54f-4352-a2b0-ca8eb32d0688	800ae597-dcdf-48e6-85e4-2c62458431da	ca47b3f2-57f9-42e5-930a-9fb788d82d3a	2018	\N
ed16b561-f225-4d30-b688-81a73f1af560	Poutník ztracené zahrady: putování bez cíle	9781262665282	856	Román sleduje spisovatelce a jejich cestu skrze velkou lásku.	\N	f36a910d-d774-4f0b-865d-4a4e739ce42e	5267a797-d212-4d5a-8c2f-4f741f783a7d	2002	\N
19dd5610-4db9-405e-944e-071a4c64904a	Tajemství tajemného lesa: putování bez cíle	9781150568060	349	Historický pohled na dlouhé cesty, který změnil divočině.	eeff29ac-393e-4c5b-a1a6-ede64f518eff	9bba6c9e-d917-472e-9fb3-f7486f98a742	1673c35b-09eb-4b71-a156-1d217749f634	2020	\N
64862e04-2bd3-4c97-99de-45f98a521a56	Dobrodružství města snů: zápas se stíny	9780118727525	582	Dobrodružství mladém muži během revoluce, plné smutných momentů.	2ad5dd3f-b2f9-4683-a9f4-3e974747cde5	9bba6c9e-d917-472e-9fb3-f7486f98a742	5267a797-d212-4d5a-8c2f-4f741f783a7d	2003	\N
c9489e1c-db3f-44c4-bcd3-6c90099d4ad7	Návrat starého hradu: hledání pravdy	9780527827977	469	Historický pohled na objevení pokladu, který změnil Paříži.	c84adfa5-977d-4f63-9cc1-bf924a75ae1a	7d0850a3-2fc4-4916-b400-7b846a51e8ad	ca47b3f2-57f9-42e5-930a-9fb788d82d3a	2002	\N
04428484-c54e-4d7c-9b4d-641bdd06b71b	Dobrodružství tajemného lesa: výprava za pokladem	9780359028412	620	Napínavý příběh starém učiteli, kde hlavní roli hrají tajemství a odhalení.	c84adfa5-977d-4f63-9cc1-bf924a75ae1a	7d0850a3-2fc4-4916-b400-7b846a51e8ad	773a6553-7226-4bc6-9296-28258a88d014	2012	\N
26f432c2-28ad-4b56-a919-a19d2ddae86c	Poutník ledového království: útěk před osudem	9781133782568	222	Román sleduje spisovatelce a jejich cestu skrze velkou lásku.	7f973681-a90e-4e2d-8ddd-220909838dd4	f36a910d-d774-4f0b-865d-4a4e739ce42e	1673c35b-09eb-4b71-a156-1d217749f634	2001	\N
393322f2-8694-4023-beb0-efec2fb706d5	Zahrada temné věže: putování bez cíle	9781595595423	675	Dobrodružství cestovateli během války, plné smutných momentů.	4f226913-73bc-45d5-811b-15d88ff5758d	cf810987-bde2-4332-a18f-a461db6be827	5267a797-d212-4d5a-8c2f-4f741f783a7d	2000	\N
ddb62abd-8e69-404a-819d-6477bbdc950d	Příběh zázračného pramene: hledání pravdy	9780251222796	178	Příběh o spisovatelce, který čelí osudu v Paříži.	\N	9bba6c9e-d917-472e-9fb3-f7486f98a742	ca47b3f2-57f9-42e5-930a-9fb788d82d3a	2023	\N
7b4d4f2f-84a8-47e0-9dec-d3048651428f	Stíny starého hradu: návrat domů	9781451276466	815	Napínavý příběh vojákovi, kde hlavní roli hrají vnitřní síla.	b51b2ed8-eed9-4b04-bc82-b6e781320f22	cf810987-bde2-4332-a18f-a461db6be827	773a6553-7226-4bc6-9296-28258a88d014	2019	\N
e8489ad7-d85a-4b42-8fee-493f5307b23e	Vzpomínky ztraceného času: návrat domů	9781647608767	735	Napínavý příběh lékařce, kde hlavní roli hrají vnitřní síla.	b51b2ed8-eed9-4b04-bc82-b6e781320f22	7d0850a3-2fc4-4916-b400-7b846a51e8ad	ca47b3f2-57f9-42e5-930a-9fb788d82d3a	2015	\N
a3efe116-8579-4af2-957d-6dc257c56324	Sen pouště naděje: dobrodružství v divočině	9781168383044	566	Dobrodružství spisovatelce během rodinné tragédie, plné napínavých momentů.	\N	f36a910d-d774-4f0b-865d-4a4e739ce42e	ca47b3f2-57f9-42e5-930a-9fb788d82d3a	2022	\N
eadefbd6-b2c1-46c4-b846-4f8a22744184	Anděl tajemného lesa: cesta za snem	9781982823818	625	Napínavý příběh lékařce, kde hlavní roli hrají odvaha a přátelství.	eeff29ac-393e-4c5b-a1a6-ede64f518eff	9bba6c9e-d917-472e-9fb3-f7486f98a742	ca47b3f2-57f9-42e5-930a-9fb788d82d3a	2000	\N
054a5366-f03e-468b-b77e-0c2579f986f2	Hvězda města snů: útěk před osudem	9780840220523	890	Napínavý příběh lékařce, kde hlavní roli hrají touha po svobodě.	bfc7cb0a-431f-4cb0-bcb0-59ecae451258	9bba6c9e-d917-472e-9fb3-f7486f98a742	5267a797-d212-4d5a-8c2f-4f741f783a7d	2002	\N
a3891a7d-98ce-4693-924f-3e3ff7770974	Město křišťálového zámku: hledání pravdy	9780170645157	835	Román sleduje vědci a jejich cestu skrze válečné strasti.	a773d6cd-c91a-4861-92c7-4299712e1b95	800ae597-dcdf-48e6-85e4-2c62458431da	773a6553-7226-4bc6-9296-28258a88d014	2002	\N
5c8dde6b-7c6b-4201-b6b9-0e7b170a7664	Hvězda královského paláce: návrat domů	9780027490268	923	Dobrodružství starém učiteli během rodinné tragédie, plné veselých momentů.	b5036804-98ef-4538-9103-11c90750d618	9bba6c9e-d917-472e-9fb3-f7486f98a742	773a6553-7226-4bc6-9296-28258a88d014	2003	\N
00b81f2e-a09a-46c9-b1ab-ab6308117e08	Legenda divoké řeky: hledání pravdy	9780290827594	944	Román sleduje vědci a jejich cestu skrze náročné rozhodnutí.	\N	cf810987-bde2-4332-a18f-a461db6be827	1673c35b-09eb-4b71-a156-1d217749f634	2016	\N
f9b788ad-2617-43df-ba6a-545d2a220033	Zámek královského paláce: hledání pravdy	9780289175583	325	Příběh o vojákovi, který objevuje tajemství v během války.	a773d6cd-c91a-4861-92c7-4299712e1b95	800ae597-dcdf-48e6-85e4-2c62458431da	ca47b3f2-57f9-42e5-930a-9fb788d82d3a	2025	\N
7a482272-36ee-4c69-b87b-cbbc1f8c79f2	Řeka ztraceného času: výprava za pokladem	9781097121755	124	Dobrodružství lékařce během objevení pokladu, plné dojemných momentů.	a773d6cd-c91a-4861-92c7-4299712e1b95	9bba6c9e-d917-472e-9fb3-f7486f98a742	773a6553-7226-4bc6-9296-28258a88d014	2019	6ec83c86-13db-4e6a-9715-22ded9b251d0
cf129447-2e40-435b-a366-4654ac4bb38e	Anděl ledového království: výprava za pokladem	9781398215016	973	Dobrodružství spisovatelce během války, plné napínavých momentů.	\N	cf810987-bde2-4332-a18f-a461db6be827	773a6553-7226-4bc6-9296-28258a88d014	2004	eadefbd6-b2c1-46c4-b846-4f8a22744184
b3bfd33f-dc19-476c-af03-91ae60b8f7ab	Zámek ztraceného času: putování bez cíle	9781170909317	775	Historický pohled na rodinné tragédie, který změnil starém hradě.	d0611158-a4b8-4c59-bcc5-50e5c730310a	cf810987-bde2-4332-a18f-a461db6be827	1673c35b-09eb-4b71-a156-1d217749f634	2013	9e25bff8-c7de-453e-871e-8fec4d35fb72
\.


--
-- Data for Name: books_authors; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.books_authors (book_id, author_id) FROM stdin;
4d729925-0c74-4c4e-b885-265652199cf5	b9cfc8b5-b3cc-4fcd-a02f-d0ee4d5d74f9
9e25bff8-c7de-453e-871e-8fec4d35fb72	b9cfc8b5-b3cc-4fcd-a02f-d0ee4d5d74f9
84eabd33-3275-4fd5-8524-818fbadc029b	3b759b76-0492-4324-85c2-bef40aa3e8cd
6ec83c86-13db-4e6a-9715-22ded9b251d0	9e3bcc96-b512-40ed-a9de-5fa3c3d5c874
7a482272-36ee-4c69-b87b-cbbc1f8c79f2	9e3bcc96-b512-40ed-a9de-5fa3c3d5c874
c6e50a2e-7cb6-4cfa-8578-c2db52c9bc2b	2732dd76-e1cc-4873-842d-2464deefff8a
613d9939-a729-409b-b904-4b183f9219eb	2732dd76-e1cc-4873-842d-2464deefff8a
e3a0bec9-c5df-46fc-a34f-fcb4900b0cfc	de66b26c-f7ec-4101-80d3-30623e5696ea
436e4d09-2319-423c-96d0-e5b7df8cd9d0	de66b26c-f7ec-4101-80d3-30623e5696ea
8a1fa577-2243-4db6-88c2-5d1a70664ec0	adf58bcf-b547-4886-ae19-793e956310a4
2bfa3a98-12f3-4e77-94c0-83041d44106c	9e3bcc96-b512-40ed-a9de-5fa3c3d5c874
8499aa6d-f7cc-44ed-af37-3c08db1c7c22	de66b26c-f7ec-4101-80d3-30623e5696ea
7d98dfc2-83c8-407f-b33d-904c001ed553	1e26b603-c6a2-4eae-a358-59c022824045
90b35dde-131c-48d6-9617-2a9909949bc4	5f8ecd9f-4baf-4a3f-8f21-ccdedf509bc0
036e5b7c-49af-4905-a5d0-05c5c5e4c6a6	1e26b603-c6a2-4eae-a358-59c022824045
1f1a8636-8f11-489e-a752-028f295208dd	3b759b76-0492-4324-85c2-bef40aa3e8cd
dbf9d2bf-dba4-4abd-9f8d-d7314a7c2865	c65759af-9004-4902-a09e-0f557d6bcb0e
b9cf660f-cec3-4eba-b1ae-12819a7accdc	a251fde2-ec97-49fd-a062-ca3787ceb101
7240234f-3660-4eb7-8897-ba793a57fd07	adf58bcf-b547-4886-ae19-793e956310a4
46953f54-de91-4812-9cad-c1c00e5b6235	c65759af-9004-4902-a09e-0f557d6bcb0e
2e8bc4bd-e7a3-457e-89ff-aad86911ddcc	c65759af-9004-4902-a09e-0f557d6bcb0e
9fd23eec-ddd2-4403-823a-e1f1b7590639	a251fde2-ec97-49fd-a062-ca3787ceb101
bcf44523-deb3-44b9-b7e6-104712de061f	3b759b76-0492-4324-85c2-bef40aa3e8cd
d4ec24fe-9c99-49e9-9575-d84da76a6357	a251fde2-ec97-49fd-a062-ca3787ceb101
678e8a78-d323-46e8-886f-972de6e3583f	2c4be0f2-acb0-4f68-9ae1-3faf5487a38a
42b7b6d5-0b3f-41e0-8983-deb711b1b4fb	616d6a4a-0650-4681-89b7-30ff5bcd1625
15f2c5a4-d00c-450c-8eb8-5feba89e9e95	2c4be0f2-acb0-4f68-9ae1-3faf5487a38a
0d091561-a820-48a7-82a4-b7cc15e6d8c7	616d6a4a-0650-4681-89b7-30ff5bcd1625
f383e8d6-893b-48f0-98ca-463cc785345f	2c4be0f2-acb0-4f68-9ae1-3faf5487a38a
a5e9b3ac-50fe-43a8-92ea-5310ed2ab23a	b9cfc8b5-b3cc-4fcd-a02f-d0ee4d5d74f9
95733110-2da1-4ae0-a1a3-e4160f1c191a	1be612db-952a-4d52-b087-b9aed16b980c
90e2c2ba-7bfa-4363-8bab-1335ad01cc26	1be612db-952a-4d52-b087-b9aed16b980c
205e541a-e6ac-40ee-ab27-8ffa274d8dc0	2732dd76-e1cc-4873-842d-2464deefff8a
2ddf16ff-f36a-4fd8-ac2e-62b1ae3d2e72	b9cfc8b5-b3cc-4fcd-a02f-d0ee4d5d74f9
e4e5c1d7-2f2d-485f-886d-bcfefa967e84	1e26b603-c6a2-4eae-a358-59c022824045
af01a7bc-cd38-44f2-81be-73ea42fb3335	adf58bcf-b547-4886-ae19-793e956310a4
91ca65c2-1051-41d8-a0d2-346011d49612	a8225590-021e-4000-b902-6de2f8ccccb3
bd87c205-3030-43f7-8d17-a89e66af1054	a8225590-021e-4000-b902-6de2f8ccccb3
b3bfd33f-dc19-476c-af03-91ae60b8f7ab	1be612db-952a-4d52-b087-b9aed16b980c
e0e5019c-ccc9-4b9a-ae31-e0b66f4ba4c6	a8225590-021e-4000-b902-6de2f8ccccb3
3ec96580-5cd0-453e-a6a5-811a138956fa	8d8cde2a-b4cc-4eeb-8e5c-2365cdf5bfab
b101e2c0-5fd5-4da4-b329-fea3a62e9bd2	5a2e5b36-f584-4bb9-846f-94ea7813a067
ed16b561-f225-4d30-b688-81a73f1af560	84c66dbe-414e-47af-993a-1d09a7d5127a
19dd5610-4db9-405e-944e-071a4c64904a	5a2e5b36-f584-4bb9-846f-94ea7813a067
64862e04-2bd3-4c97-99de-45f98a521a56	84c66dbe-414e-47af-993a-1d09a7d5127a
c9489e1c-db3f-44c4-bcd3-6c90099d4ad7	8d8cde2a-b4cc-4eeb-8e5c-2365cdf5bfab
04428484-c54e-4d7c-9b4d-641bdd06b71b	1be612db-952a-4d52-b087-b9aed16b980c
26f432c2-28ad-4b56-a919-a19d2ddae86c	84c66dbe-414e-47af-993a-1d09a7d5127a
393322f2-8694-4023-beb0-efec2fb706d5	58f1ea7d-6e35-4eb3-9651-455a5436adfa
cf129447-2e40-435b-a366-4654ac4bb38e	8d8cde2a-b4cc-4eeb-8e5c-2365cdf5bfab
ddb62abd-8e69-404a-819d-6477bbdc950d	5cb98e1b-5dc8-477a-b686-d62bff118d6d
7b4d4f2f-84a8-47e0-9dec-d3048651428f	58f1ea7d-6e35-4eb3-9651-455a5436adfa
e8489ad7-d85a-4b42-8fee-493f5307b23e	5cb98e1b-5dc8-477a-b686-d62bff118d6d
a3efe116-8579-4af2-957d-6dc257c56324	58f1ea7d-6e35-4eb3-9651-455a5436adfa
eadefbd6-b2c1-46c4-b846-4f8a22744184	0834dcd7-f466-44de-9402-cf413dd1c10d
054a5366-f03e-468b-b77e-0c2579f986f2	58f1ea7d-6e35-4eb3-9651-455a5436adfa
a3891a7d-98ce-4693-924f-3e3ff7770974	5cb98e1b-5dc8-477a-b686-d62bff118d6d
5c8dde6b-7c6b-4201-b6b9-0e7b170a7664	5a2e5b36-f584-4bb9-846f-94ea7813a067
00b81f2e-a09a-46c9-b1ab-ab6308117e08	0834dcd7-f466-44de-9402-cf413dd1c10d
f9b788ad-2617-43df-ba6a-545d2a220033	0834dcd7-f466-44de-9402-cf413dd1c10d
\.


--
-- Data for Name: books_genres; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.books_genres (book_id, genre_id) FROM stdin;
4d729925-0c74-4c4e-b885-265652199cf5	3e1438be-8c72-4012-a2bf-d493a3cfce2a
4d729925-0c74-4c4e-b885-265652199cf5	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
4d729925-0c74-4c4e-b885-265652199cf5	b3e6b2a2-fcbd-4d58-924d-cfd938afd34d
9e25bff8-c7de-453e-871e-8fec4d35fb72	f9df170b-7f68-4090-a3d5-87354bb34145
9e25bff8-c7de-453e-871e-8fec4d35fb72	3e1438be-8c72-4012-a2bf-d493a3cfce2a
9e25bff8-c7de-453e-871e-8fec4d35fb72	448d5394-3da9-483a-895d-1c92e0ef77ae
6ec83c86-13db-4e6a-9715-22ded9b251d0	3e1438be-8c72-4012-a2bf-d493a3cfce2a
6ec83c86-13db-4e6a-9715-22ded9b251d0	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
6ec83c86-13db-4e6a-9715-22ded9b251d0	3e1438be-8c72-4012-a2bf-d493a3cfce2a
7a482272-36ee-4c69-b87b-cbbc1f8c79f2	3e1438be-8c72-4012-a2bf-d493a3cfce2a
7a482272-36ee-4c69-b87b-cbbc1f8c79f2	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
7a482272-36ee-4c69-b87b-cbbc1f8c79f2	3e1438be-8c72-4012-a2bf-d493a3cfce2a
c6e50a2e-7cb6-4cfa-8578-c2db52c9bc2b	3e1438be-8c72-4012-a2bf-d493a3cfce2a
c6e50a2e-7cb6-4cfa-8578-c2db52c9bc2b	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
c6e50a2e-7cb6-4cfa-8578-c2db52c9bc2b	3e1438be-8c72-4012-a2bf-d493a3cfce2a
613d9939-a729-409b-b904-4b183f9219eb	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
613d9939-a729-409b-b904-4b183f9219eb	3e1438be-8c72-4012-a2bf-d493a3cfce2a
613d9939-a729-409b-b904-4b183f9219eb	448d5394-3da9-483a-895d-1c92e0ef77ae
e3a0bec9-c5df-46fc-a34f-fcb4900b0cfc	3e1438be-8c72-4012-a2bf-d493a3cfce2a
e3a0bec9-c5df-46fc-a34f-fcb4900b0cfc	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
e3a0bec9-c5df-46fc-a34f-fcb4900b0cfc	f9df170b-7f68-4090-a3d5-87354bb34145
436e4d09-2319-423c-96d0-e5b7df8cd9d0	3e1438be-8c72-4012-a2bf-d493a3cfce2a
436e4d09-2319-423c-96d0-e5b7df8cd9d0	f9df170b-7f68-4090-a3d5-87354bb34145
436e4d09-2319-423c-96d0-e5b7df8cd9d0	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
8a1fa577-2243-4db6-88c2-5d1a70664ec0	d13d2c9e-1cb8-46b1-87da-baae334b64b3
8a1fa577-2243-4db6-88c2-5d1a70664ec0	3e1438be-8c72-4012-a2bf-d493a3cfce2a
8a1fa577-2243-4db6-88c2-5d1a70664ec0	448d5394-3da9-483a-895d-1c92e0ef77ae
2bfa3a98-12f3-4e77-94c0-83041d44106c	3e1438be-8c72-4012-a2bf-d493a3cfce2a
2bfa3a98-12f3-4e77-94c0-83041d44106c	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
2bfa3a98-12f3-4e77-94c0-83041d44106c	3e1438be-8c72-4012-a2bf-d493a3cfce2a
8499aa6d-f7cc-44ed-af37-3c08db1c7c22	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
8499aa6d-f7cc-44ed-af37-3c08db1c7c22	f9df170b-7f68-4090-a3d5-87354bb34145
8499aa6d-f7cc-44ed-af37-3c08db1c7c22	3e1438be-8c72-4012-a2bf-d493a3cfce2a
7d98dfc2-83c8-407f-b33d-904c001ed553	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
7d98dfc2-83c8-407f-b33d-904c001ed553	b3e6b2a2-fcbd-4d58-924d-cfd938afd34d
7d98dfc2-83c8-407f-b33d-904c001ed553	f9df170b-7f68-4090-a3d5-87354bb34145
90b35dde-131c-48d6-9617-2a9909949bc4	3e1438be-8c72-4012-a2bf-d493a3cfce2a
90b35dde-131c-48d6-9617-2a9909949bc4	448d5394-3da9-483a-895d-1c92e0ef77ae
90b35dde-131c-48d6-9617-2a9909949bc4	f9df170b-7f68-4090-a3d5-87354bb34145
036e5b7c-49af-4905-a5d0-05c5c5e4c6a6	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
036e5b7c-49af-4905-a5d0-05c5c5e4c6a6	3e1438be-8c72-4012-a2bf-d493a3cfce2a
036e5b7c-49af-4905-a5d0-05c5c5e4c6a6	3e1438be-8c72-4012-a2bf-d493a3cfce2a
1f1a8636-8f11-489e-a752-028f295208dd	448d5394-3da9-483a-895d-1c92e0ef77ae
1f1a8636-8f11-489e-a752-028f295208dd	3e1438be-8c72-4012-a2bf-d493a3cfce2a
1f1a8636-8f11-489e-a752-028f295208dd	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
dbf9d2bf-dba4-4abd-9f8d-d7314a7c2865	3e1438be-8c72-4012-a2bf-d493a3cfce2a
dbf9d2bf-dba4-4abd-9f8d-d7314a7c2865	3e1438be-8c72-4012-a2bf-d493a3cfce2a
dbf9d2bf-dba4-4abd-9f8d-d7314a7c2865	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
b9cf660f-cec3-4eba-b1ae-12819a7accdc	3e1438be-8c72-4012-a2bf-d493a3cfce2a
b9cf660f-cec3-4eba-b1ae-12819a7accdc	3e1438be-8c72-4012-a2bf-d493a3cfce2a
b9cf660f-cec3-4eba-b1ae-12819a7accdc	448d5394-3da9-483a-895d-1c92e0ef77ae
7240234f-3660-4eb7-8897-ba793a57fd07	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
7240234f-3660-4eb7-8897-ba793a57fd07	3e1438be-8c72-4012-a2bf-d493a3cfce2a
7240234f-3660-4eb7-8897-ba793a57fd07	d13d2c9e-1cb8-46b1-87da-baae334b64b3
46953f54-de91-4812-9cad-c1c00e5b6235	3e1438be-8c72-4012-a2bf-d493a3cfce2a
46953f54-de91-4812-9cad-c1c00e5b6235	448d5394-3da9-483a-895d-1c92e0ef77ae
46953f54-de91-4812-9cad-c1c00e5b6235	3e1438be-8c72-4012-a2bf-d493a3cfce2a
2e8bc4bd-e7a3-457e-89ff-aad86911ddcc	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
2e8bc4bd-e7a3-457e-89ff-aad86911ddcc	3e1438be-8c72-4012-a2bf-d493a3cfce2a
2e8bc4bd-e7a3-457e-89ff-aad86911ddcc	448d5394-3da9-483a-895d-1c92e0ef77ae
9fd23eec-ddd2-4403-823a-e1f1b7590639	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
9fd23eec-ddd2-4403-823a-e1f1b7590639	b3e6b2a2-fcbd-4d58-924d-cfd938afd34d
9fd23eec-ddd2-4403-823a-e1f1b7590639	f9df170b-7f68-4090-a3d5-87354bb34145
bcf44523-deb3-44b9-b7e6-104712de061f	3e1438be-8c72-4012-a2bf-d493a3cfce2a
bcf44523-deb3-44b9-b7e6-104712de061f	3e1438be-8c72-4012-a2bf-d493a3cfce2a
bcf44523-deb3-44b9-b7e6-104712de061f	3e1438be-8c72-4012-a2bf-d493a3cfce2a
d4ec24fe-9c99-49e9-9575-d84da76a6357	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
d4ec24fe-9c99-49e9-9575-d84da76a6357	3e1438be-8c72-4012-a2bf-d493a3cfce2a
d4ec24fe-9c99-49e9-9575-d84da76a6357	3e1438be-8c72-4012-a2bf-d493a3cfce2a
678e8a78-d323-46e8-886f-972de6e3583f	3e1438be-8c72-4012-a2bf-d493a3cfce2a
678e8a78-d323-46e8-886f-972de6e3583f	3e1438be-8c72-4012-a2bf-d493a3cfce2a
678e8a78-d323-46e8-886f-972de6e3583f	3e1438be-8c72-4012-a2bf-d493a3cfce2a
42b7b6d5-0b3f-41e0-8983-deb711b1b4fb	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
42b7b6d5-0b3f-41e0-8983-deb711b1b4fb	3e1438be-8c72-4012-a2bf-d493a3cfce2a
42b7b6d5-0b3f-41e0-8983-deb711b1b4fb	f9df170b-7f68-4090-a3d5-87354bb34145
15f2c5a4-d00c-450c-8eb8-5feba89e9e95	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
15f2c5a4-d00c-450c-8eb8-5feba89e9e95	f9df170b-7f68-4090-a3d5-87354bb34145
15f2c5a4-d00c-450c-8eb8-5feba89e9e95	3e1438be-8c72-4012-a2bf-d493a3cfce2a
0d091561-a820-48a7-82a4-b7cc15e6d8c7	3e1438be-8c72-4012-a2bf-d493a3cfce2a
0d091561-a820-48a7-82a4-b7cc15e6d8c7	448d5394-3da9-483a-895d-1c92e0ef77ae
0d091561-a820-48a7-82a4-b7cc15e6d8c7	f9df170b-7f68-4090-a3d5-87354bb34145
f383e8d6-893b-48f0-98ca-463cc785345f	3e1438be-8c72-4012-a2bf-d493a3cfce2a
f383e8d6-893b-48f0-98ca-463cc785345f	3e1438be-8c72-4012-a2bf-d493a3cfce2a
f383e8d6-893b-48f0-98ca-463cc785345f	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
a5e9b3ac-50fe-43a8-92ea-5310ed2ab23a	d13d2c9e-1cb8-46b1-87da-baae334b64b3
a5e9b3ac-50fe-43a8-92ea-5310ed2ab23a	3e1438be-8c72-4012-a2bf-d493a3cfce2a
a5e9b3ac-50fe-43a8-92ea-5310ed2ab23a	448d5394-3da9-483a-895d-1c92e0ef77ae
95733110-2da1-4ae0-a1a3-e4160f1c191a	3e1438be-8c72-4012-a2bf-d493a3cfce2a
95733110-2da1-4ae0-a1a3-e4160f1c191a	3e1438be-8c72-4012-a2bf-d493a3cfce2a
95733110-2da1-4ae0-a1a3-e4160f1c191a	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
90e2c2ba-7bfa-4363-8bab-1335ad01cc26	3e1438be-8c72-4012-a2bf-d493a3cfce2a
90e2c2ba-7bfa-4363-8bab-1335ad01cc26	448d5394-3da9-483a-895d-1c92e0ef77ae
90e2c2ba-7bfa-4363-8bab-1335ad01cc26	3e1438be-8c72-4012-a2bf-d493a3cfce2a
84eabd33-3275-4fd5-8524-818fbadc029b	448d5394-3da9-483a-895d-1c92e0ef77ae
84eabd33-3275-4fd5-8524-818fbadc029b	f9df170b-7f68-4090-a3d5-87354bb34145
84eabd33-3275-4fd5-8524-818fbadc029b	3e1438be-8c72-4012-a2bf-d493a3cfce2a
205e541a-e6ac-40ee-ab27-8ffa274d8dc0	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
205e541a-e6ac-40ee-ab27-8ffa274d8dc0	3e1438be-8c72-4012-a2bf-d493a3cfce2a
205e541a-e6ac-40ee-ab27-8ffa274d8dc0	448d5394-3da9-483a-895d-1c92e0ef77ae
2ddf16ff-f36a-4fd8-ac2e-62b1ae3d2e72	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
2ddf16ff-f36a-4fd8-ac2e-62b1ae3d2e72	f9df170b-7f68-4090-a3d5-87354bb34145
2ddf16ff-f36a-4fd8-ac2e-62b1ae3d2e72	3e1438be-8c72-4012-a2bf-d493a3cfce2a
e4e5c1d7-2f2d-485f-886d-bcfefa967e84	448d5394-3da9-483a-895d-1c92e0ef77ae
e4e5c1d7-2f2d-485f-886d-bcfefa967e84	f9df170b-7f68-4090-a3d5-87354bb34145
e4e5c1d7-2f2d-485f-886d-bcfefa967e84	d13d2c9e-1cb8-46b1-87da-baae334b64b3
af01a7bc-cd38-44f2-81be-73ea42fb3335	3e1438be-8c72-4012-a2bf-d493a3cfce2a
af01a7bc-cd38-44f2-81be-73ea42fb3335	3e1438be-8c72-4012-a2bf-d493a3cfce2a
af01a7bc-cd38-44f2-81be-73ea42fb3335	448d5394-3da9-483a-895d-1c92e0ef77ae
91ca65c2-1051-41d8-a0d2-346011d49612	acc6ff0c-6101-4e2b-adcf-eab7978b33d8
\.


--
-- Data for Name: countries; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.countries (country_id, name) FROM stdin;
6378a4d4-390b-446d-8541-e7239fc9dc90	Česká republika
00be0e3a-c92c-4696-9686-d503ef4f3548	Argentina
6e5b7f20-9b8e-412d-a740-14e528989144	Mexiko
b2881310-e2ff-4496-818c-d3cb99902cc1	Paraguay
feb4429f-77ff-47c8-9fe6-d17fed8d949b	Chorvatsko
567e11ce-a010-411f-8509-acb65d049ce7	Itálie
be697431-f394-46c7-b017-63b803fd9073	Francie
0f1249ec-f650-4ac5-932a-7a6d05b4819e	Německo
2f210199-8f43-45e1-9817-f838dc872d21	Španělsko
f28d0468-49cc-414f-bd92-efb4d34ff912	Polsko
\.


--
-- Data for Name: genres; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.genres (genre_id, name) FROM stdin;
d13d2c9e-1cb8-46b1-87da-baae334b64b3	Fantasy
b3e6b2a2-fcbd-4d58-924d-cfd938afd34d	Sci-fi
3e1438be-8c72-4012-a2bf-d493a3cfce2a	Román
448d5394-3da9-483a-895d-1c92e0ef77ae	Thriller
5f273950-fffa-4192-9002-4f1ba66a4df9	Horor
9bdc2c6f-ab34-41ff-9e03-e021bbca50f0	Detektivka
f9df170b-7f68-4090-a3d5-87354bb34145	Historický román
cfa6e237-d1e4-46e5-8fb8-2a3264bc2345	Biografie
acc6ff0c-6101-4e2b-adcf-eab7978b33d8	Cestopis
e7575594-64b0-4529-a91b-54bc1f8d077d	Poezie
\.


--
-- Data for Name: languages; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.languages (language_id, name) FROM stdin;
f36a910d-d774-4f0b-865d-4a4e739ce42e	Čeština
800ae597-dcdf-48e6-85e4-2c62458431da	Angličtina
9bba6c9e-d917-472e-9fb3-f7486f98a742	Francouzština
7d0850a3-2fc4-4916-b400-7b846a51e8ad	Němčina
cf810987-bde2-4332-a18f-a461db6be827	Španělština
\.


--
-- Data for Name: publishers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.publishers (publisher_id, name, founded, country_id) FROM stdin;
09fe256f-313e-4250-9ffe-bb910ff64f27	Nakladatelství Slovo	1993-01-01	6378a4d4-390b-446d-8541-e7239fc9dc90
d4f93c0f-14bf-4c3e-9e94-877ca23288f5	Edice Most	2001-06-15	6378a4d4-390b-446d-8541-e7239fc9dc90
d0611158-a4b8-4c59-bcc5-50e5c730310a	Knižní klub Praha	1990-05-10	6378a4d4-390b-446d-8541-e7239fc9dc90
4f226913-73bc-45d5-811b-15d88ff5758d	Editorial Patagonia	1985-03-12	00be0e3a-c92c-4696-9686-d503ef4f3548
b51b2ed8-eed9-4b04-bc82-b6e781320f22	Libros del Sur	1998-07-20	00be0e3a-c92c-4696-9686-d503ef4f3548
2ad5dd3f-b2f9-4683-a9f4-3e974747cde5	Casa de Letras	2003-09-05	6e5b7f20-9b8e-412d-a740-14e528989144
fe698774-81f9-4114-990b-6c85849d5151	Editorial Azteca	1995-12-30	6e5b7f20-9b8e-412d-a740-14e528989144
c6ad42d0-3e1e-4afe-96e7-b192f9e806bb	Ediciones Ñandutí	2007-04-11	b2881310-e2ff-4496-818c-d3cb99902cc1
a773d6cd-c91a-4861-92c7-4299712e1b95	Paraguay Publicaciones	1999-10-08	b2881310-e2ff-4496-818c-d3cb99902cc1
d7f4b28a-b3a2-49ca-8b66-659cf5987b08	Knjiga Zagreb	1980-08-22	feb4429f-77ff-47c8-9fe6-d17fed8d949b
7f973681-a90e-4e2d-8ddd-220909838dd4	Dalmatinska Izdanja	2010-02-18	feb4429f-77ff-47c8-9fe6-d17fed8d949b
eeff29ac-393e-4c5b-a1a6-ede64f518eff	Editrice Roma	1975-11-17	567e11ce-a010-411f-8509-acb65d049ce7
26015f35-3313-4109-8861-f50dbf59b12d	Libri di Firenze	2004-05-06	567e11ce-a010-411f-8509-acb65d049ce7
8fd3fe04-ed88-4b3f-9eff-fb207522991c	Éditions Lumière	1965-03-25	be697431-f394-46c7-b017-63b803fd9073
c84adfa5-977d-4f63-9cc1-bf924a75ae1a	Maison du Livre	2000-09-13	be697431-f394-46c7-b017-63b803fd9073
6af877ce-b6cd-4fbb-b276-d327bcd7ca34	Bücherhaus Berlin	1988-07-19	0f1249ec-f650-4ac5-932a-7a6d05b4819e
b5036804-98ef-4538-9103-11c90750d618	Verlag Rhein	1992-10-30	0f1249ec-f650-4ac5-932a-7a6d05b4819e
935a47b6-4fbb-4780-89dc-4e1c05eeae85	Editorial Sol	1991-12-03	2f210199-8f43-45e1-9817-f838dc872d21
bfc7cb0a-431f-4cb0-bcb0-59ecae451258	Libros Ibéricos	1982-05-01	2f210199-8f43-45e1-9817-f838dc872d21
def18138-d54f-4352-a2b0-ca8eb32d0688	Casa del Saber	2006-08-22	2f210199-8f43-45e1-9817-f838dc872d21
\.


--
-- Name: audit_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.audit_log_id_seq', 2, true);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: authors author_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.authors
    ADD CONSTRAINT author_pkey PRIMARY KEY (author_id);


--
-- Name: book_formats book_format_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.book_formats
    ADD CONSTRAINT book_format_name_key UNIQUE (name);


--
-- Name: book_formats book_format_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.book_formats
    ADD CONSTRAINT book_format_pkey PRIMARY KEY (book_format_id);


--
-- Name: books book_isbn_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.books
    ADD CONSTRAINT book_isbn_key UNIQUE (isbn);


--
-- Name: books book_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.books
    ADD CONSTRAINT book_pkey PRIMARY KEY (book_id);


--
-- Name: countries country_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT country_name_key UNIQUE (name);


--
-- Name: countries country_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.countries
    ADD CONSTRAINT country_pkey PRIMARY KEY (country_id);


--
-- Name: genres genre_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.genres
    ADD CONSTRAINT genre_name_key UNIQUE (name);


--
-- Name: genres genre_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.genres
    ADD CONSTRAINT genre_pkey PRIMARY KEY (genre_id);


--
-- Name: languages language_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.languages
    ADD CONSTRAINT language_name_key UNIQUE (name);


--
-- Name: languages language_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.languages
    ADD CONSTRAINT language_pkey PRIMARY KEY (language_id);


--
-- Name: publishers publisher_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.publishers
    ADD CONSTRAINT publisher_pkey PRIMARY KEY (publisher_id);


--
-- Name: books_title_fulltext_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX books_title_fulltext_idx ON public.books USING gin (to_tsvector('public.cs_search'::regconfig, (title)::text));


--
-- Name: idx_fulltext_biografie; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_fulltext_biografie ON public.authors USING gin (to_tsvector('simple'::regconfig, biography));


--
-- Name: idx_unikátni_kniha_autora; Type: INDEX; Schema: public; Owner: postgres
--

CREATE UNIQUE INDEX "idx_unikátni_kniha_autora" ON public.books USING btree (title, publication_year);


--
-- Name: books trg_audit_update_kniha; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_audit_update_kniha BEFORE UPDATE OF title ON public.books FOR EACH ROW EXECUTE FUNCTION public.f_audit_knihy();


--
-- Name: authors author_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.authors
    ADD CONSTRAINT author_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.countries(country_id);


--
-- Name: books book_format_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.books
    ADD CONSTRAINT book_format_id_fkey FOREIGN KEY (format_id) REFERENCES public.book_formats(book_format_id);


--
-- Name: books_genres book_genre_book_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.books_genres
    ADD CONSTRAINT book_genre_book_id_fkey FOREIGN KEY (book_id) REFERENCES public.books(book_id) ON DELETE CASCADE;


--
-- Name: books_genres book_genre_genre_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.books_genres
    ADD CONSTRAINT book_genre_genre_id_fkey FOREIGN KEY (genre_id) REFERENCES public.genres(genre_id) ON DELETE CASCADE;


--
-- Name: books book_language_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.books
    ADD CONSTRAINT book_language_id_fkey FOREIGN KEY (language_id) REFERENCES public.languages(language_id);


--
-- Name: books book_publisher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.books
    ADD CONSTRAINT book_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.publishers(publisher_id);


--
-- Name: books_authors books_authors_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.books_authors
    ADD CONSTRAINT books_authors_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.authors(author_id) ON DELETE CASCADE;


--
-- Name: books_authors books_authors_book_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.books_authors
    ADD CONSTRAINT books_authors_book_id_fkey FOREIGN KEY (book_id) REFERENCES public.books(book_id) ON DELETE CASCADE;


--
-- Name: books fk_books_previous; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.books
    ADD CONSTRAINT fk_books_previous FOREIGN KEY (previous_book_id) REFERENCES public.books(book_id);


--
-- Name: publishers publisher_country_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.publishers
    ADD CONSTRAINT publisher_country_id_fkey FOREIGN KEY (country_id) REFERENCES public.countries(country_id);


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: postgres
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- Name: TABLE audit_log; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.audit_log TO student_role;


--
-- Name: TABLE authors; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.authors TO student_role;


--
-- Name: TABLE book_formats; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.book_formats TO student_role;


--
-- Name: TABLE books; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.books TO student_role;


--
-- Name: TABLE books_authors; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.books_authors TO student_role;


--
-- Name: TABLE languages; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.languages TO student_role;


--
-- Name: TABLE publishers; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.publishers TO student_role;


--
-- Name: TABLE books_full_view; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.books_full_view TO student_role;


--
-- Name: TABLE books_genres; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.books_genres TO student_role;


--
-- Name: TABLE countries; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.countries TO student_role;


--
-- Name: TABLE genres; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT ON TABLE public.genres TO student_role;


--
-- PostgreSQL database dump complete
--

\unrestrict WQXuK37zJM5cZeO44LcU1gVCvKQRXOzUgSRKX1zIW8f181mnBzIZG0aZZIrmGxH

