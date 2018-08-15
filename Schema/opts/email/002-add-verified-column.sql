ALTER TABLE odin.identity ADD COLUMN
    verified BOOLEAN DEFAULT FALSE;

ALTER TABLE odin.identity_email_ledger ADD COLUMN
    verified BOOLEAN DEFAULT FALSE;

CREATE OR REPLACE FUNCTION odin.identity_email_ledger_insert() RETURNS TRIGGER AS $body$
    BEGIN
        INSERT INTO odin.identity (id, email, verified)
            VALUES (NEW.identity_id, NEW.email, NEW.verified)
            ON CONFLICT (id) DO UPDATE SET
                email = EXCLUDED.email;
                verified = EXCLUDED.verified
        RETURN NULL;
    END;
    $body$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = odin;