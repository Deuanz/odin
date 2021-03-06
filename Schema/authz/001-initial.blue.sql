INSERT INTO odin.module VALUES('authz');
INSERT INTO odin.migration VALUES('authz', '001-initial.blue.sql');


-- Super users will always be allowed every permission
ALTER TABLE odin.identity ADD COLUMN
    is_superuser boolean NOT NULL DEFAULT 'f';

CREATE TABLE odin.identity_superuser_ledger (
    reference text NOT NULL,
    identity_id text NOT NULL,
    CONSTRAINT credentials_superuser_ledger_identity_fkey
        FOREIGN KEY (identity_id)
        REFERENCES odin.identity (id) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION DEFERRABLE,
    CONSTRAINT odin_identity_superuser_ledger_pk PRIMARY KEY (reference, identity_id),

    changed timestamp with time zone NOT NULL DEFAULT now(),
    pg_user text NOT NULL DEFAULT current_user,

    superuser boolean NOT NULL,

    annotation json NOT NULL DEFAULT '{}'
);
CREATE FUNCTION odin.identity_superuser_ledger_insert() RETURNS TRIGGER AS $body$
    BEGIN
        INSERT INTO odin.identity (id, is_superuser)
            VALUES (NEW.identity_id, NEW.superuser)
            ON CONFLICT (id) DO UPDATE SET
                is_superuser = EXCLUDED.is_superuser;
        RETURN NULL;
    END
    $body$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = odin;
CREATE TRIGGER odin_identity_superuser_ledger_insert_trigger
    AFTER INSERT ON odin.identity_superuser_ledger
    FOR EACH ROW EXECUTE PROCEDURE odin.identity_superuser_ledger_insert();


-- Groups are used to manage users and permissions
CREATE TABLE odin.group (
    slug text NOT NULL CHECK (odin.url_safe(slug)),
    CONSTRAINT odin_group_pk PRIMARY KEY (slug),

    description text NOT NULL DEFAULT ''
);

CREATE TABLE odin.group_ledger (
    reference text NOT NULL,
    group_slug text NOT NULL,
    CONSTRAINT odin_group_ledger_group_fkey
        FOREIGN KEY (group_slug)
        REFERENCES odin.group (slug) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION DEFERRABLE,
    CONSTRAINT odin_group_ledger_pk PRIMARY KEY (reference, group_slug),

    changed timestamp with time zone NOT NULL DEFAULT now(),
    pg_user text NOT NULL DEFAULT current_user,

    description text NOT NULL DEFAULT '',

    annotation json NOT NULL DEFAULT '{}'
);
CREATE FUNCTION odin.group_ledger_insert() RETURNS TRIGGER AS $body$
    BEGIN
        INSERT INTO odin.group (slug, description)
            VALUES (NEW.group_slug, NEW.description)
            ON CONFLICT (slug) DO UPDATE SET
                description = EXCLUDED.description;
        RETURN NEW;
    END
    $body$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = odin;
CREATE TRIGGER odin_group_ledger_insert_trigger
    BEFORE INSERT ON odin.group_ledger
    FOR EACH ROW EXECUTE PROCEDURE odin.group_ledger_insert();

INSERT INTO odin.group_ledger
    (reference, group_slug, description) VALUES
    (current_setting('odin.reference'), 'auditor',
        'Can view most of the user and group set up and audit trails in the system'),
    (current_setting('odin.reference'), 'admin-group',
        'Can create groups and assign permissions to them'),
    (current_setting('odin.reference'), 'admin-user',
        'Can create users and assign groups to ');


-- Users can be assigned to any number of groups
CREATE TABLE odin.group_membership (
    identity_id text NOT NULL,
    CONSTRAINT odin_group_membership_identity_fkey
        FOREIGN KEY (identity_id)
        REFERENCES odin.identity (id) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION DEFERRABLE,
    group_slug text NOT NULL,
    CONSTRAINT odin_group_membership_group_fkey
        FOREIGN KEY (group_slug)
        REFERENCES odin.group (slug) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION DEFERRABLE,
    CONSTRAINT odin_group_membership_pk PRIMARY KEY (identity_id, group_slug)
);
CREATE TABLE odin.group_membership_ledger (
    reference text NOT NULL,
    identity_id text NOT NULL,
    CONSTRAINT odin_group_membership_ledger_identity_fkey
        FOREIGN KEY (identity_id)
        REFERENCES odin.identity (id) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION DEFERRABLE,
    group_slug text NOT NULL,
    CONSTRAINT odin_group_membership_ledger_group_fkey
        FOREIGN KEY (group_slug)
        REFERENCES odin.group (slug) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION DEFERRABLE,
    CONSTRAINT odin_group_membership_ledger_pk PRIMARY KEY
        (reference, identity_id, group_slug),

    changed timestamp with time zone NOT NULL DEFAULT now(),
    pg_user text NOT NULL DEFAULT current_user,

    -- Inserrt with true to add the membership, with false to remove it
    member boolean NOT NULL,

    annotation json NOT NULL DEFAULT '{}'
);
CREATE FUNCTION odin.group_membership_ledger_insert() RETURNS TRIGGER AS $body$
    BEGIN
        IF NEW.member THEN
            INSERT INTO odin.group_membership (identity_id, group_slug)
                VALUES (NEW.identity_id, NEW.group_slug)
                ON CONFLICT DO NOTHING;
        ELSE
            DELETE FROM odin.group_membership
                WHERE identity_id=NEW.identity_id AND group_slug=NEW.group_slug;
        END if;
        RETURN NEW;
    END
    $body$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = odin;
CREATE TRIGGER odin_group_membership_ledger_insert_trigger
    BEFORE INSERT ON odin.group_membership_ledger
    FOR EACH ROW EXECUTE PROCEDURE odin.group_membership_ledger_insert();


-- Permissions are application level names that control specific features
CREATE TABLE odin.permission (
    slug text NOT NULL CHECK (odin.url_safe(slug)),
    CONSTRAINT odin_permission_pk PRIMARY KEY (slug),

    description text NOT NULL DEFAULT ''
);

CREATE TABLE odin.permission_ledger (
    reference text NOT NULL,
    permission_slug text NOT NULL,
    CONSTRAINT odin_permission_ledger_permission_fkey
        FOREIGN KEY (permission_slug)
        REFERENCES odin.permission (slug) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION DEFERRABLE,
    CONSTRAINT odin_permission_ledger_pk PRIMARY KEY (reference, permission_slug),

    changed timestamp with time zone NOT NULL DEFAULT now(),
    pg_user text NOT NULL DEFAULT current_user,

    description text NOT NULL DEFAULT '',

    annotation json NOT NULL DEFAULT '{}'
);
CREATE FUNCTION odin.permission_ledger_insert() RETURNS TRIGGER AS $body$
    BEGIN
        INSERT INTO odin.permission (slug, description)
            VALUES (NEW.permission_slug, NEW.description)
            ON CONFLICT (slug) DO UPDATE SET
                description = EXCLUDED.description;
        RETURN NEW;
    END
    $body$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = odin;
CREATE TRIGGER odin_permission_ledger_insert_trigger
    BEFORE INSERT ON odin.permission_ledger
    FOR EACH ROW EXECUTE PROCEDURE odin.permission_ledger_insert();

INSERT INTO odin.permission_ledger
    (reference, permission_slug, description) VALUES
    (current_setting('odin.reference'), 'create-user',
        'Can create a user'),
    (current_setting('odin.reference'), 'create-group',
        'Can create a group');


-- Groups are granted any number of permissions
CREATE TABLE odin.group_grant (
    group_slug text NOT NULL,
    CONSTRAINT odin_group_grant_group_fkey
        FOREIGN KEY (group_slug)
        REFERENCES odin.group (slug) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION DEFERRABLE,
    permission_slug text NOT NULL,
    CONSTRAINT odin_group_grant_permission_fkey
        FOREIGN KEY (permission_slug)
        REFERENCES odin.permission (slug) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION DEFERRABLE,
    CONSTRAINT odin_group_grant_pk PRIMARY KEY (group_slug, permission_slug)
);

CREATE TABLE odin.group_grant_ledger (
    reference text NOT NULL,
    group_slug text NOT NULL,
    CONSTRAINT odin_group_grant_ledger_group_fkey
        FOREIGN KEY (group_slug)
        REFERENCES odin.group (slug) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION DEFERRABLE,
    permission_slug text NOT NULL,
    CONSTRAINT odin_group_grant_ledger_permission_fkey
        FOREIGN KEY (permission_slug)
        REFERENCES odin.permission (slug) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE NO ACTION DEFERRABLE,
    CONSTRAINT odin_group_grant_ledger_pk PRIMARY KEY
        (reference, group_slug, permission_slug),

    changed timestamp with time zone NOT NULL DEFAULT now(),
    pg_user text NOT NULL DEFAULT current_user,

    -- Inserrt with true to add the permission, with false to remove it
    allows boolean NOT NULL,

    annotation json NOT NULL DEFAULT '{}'
);
CREATE FUNCTION odin.group_grant_ledger_insert() RETURNS TRIGGER AS $body$
    BEGIN
        IF NEW.allows THEN
            INSERT INTO odin.group_grant (group_slug, permission_slug)
                VALUES (NEW.group_slug, NEW.permission_slug)
                ON CONFLICT DO NOTHING;
        ELSE
            DELETE FROM odin.group_grant
                WHERE group_slug = NEW.group_slug AND permission_slug = NEW.permission_slug;
        END if;
        RETURN NEW;
    END
    $body$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = odin;
CREATE TRIGGER odin_group_grant_ledger_insert_trigger
    BEFORE INSERT ON odin.group_grant_ledger
    FOR EACH ROW EXECUTE PROCEDURE odin.group_grant_ledger_insert();


CREATE VIEW odin.user_permission AS
    SELECT DISTINCT
            odin.identity.id as identity_id,
            odin.permission.slug AS permission_slug,
            odin.permission.description
        FROM odin.identity
        JOIN odin.group_membership ON
            (odin.identity.id=odin.group_membership.identity_id
                 OR odin.identity.is_superuser)
        JOIN odin.group_grant ON
            (odin.group_grant.group_slug=odin.group_membership.group_slug
                 OR odin.identity.is_superuser)
        JOIN odin.permission ON
            (odin.permission.slug=odin.group_grant.permission_slug
                OR odin.identity.is_superuser)
        WHERE odin.identity.expires IS NULL OR odin.identity.expires > now();


INSERT INTO odin.group_grant_ledger
    (reference, group_slug, permission_slug, allows) VALUES
    (current_setting('odin.reference'), 'admin-group', 'create-group', 't'),
    (current_setting('odin.reference'), 'admin-user', 'create-user', 't');

