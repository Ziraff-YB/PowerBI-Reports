
IF NOT EXISTS
(
    SELECT 1
    FROM sys.change_tracking_databases
    WHERE database_id = DB_ID(N'Yellowblock')
)
BEGIN
    ALTER DATABASE [Yellowblock]
    SET CHANGE_TRACKING = ON
    (
        CHANGE_RETENTION = 7 DAYS,
        AUTO_CLEANUP = ON
    );
END;

SELECT
    s.name AS SchemaName,
    t.name AS TableName,
    CASE
        WHEN ct.object_id IS NOT NULL THEN 'ENABLED'
        ELSE 'NOT ENABLED'
    END AS ChangeTrackingStatus
FROM sys.tables t
INNER JOIN sys.schemas s
    ON s.schema_id = t.schema_id
LEFT JOIN sys.change_tracking_tables ct
    ON ct.object_id = t.object_id
WHERE
    (s.name = 'Member' AND t.name IN ('Customer', 'CustomerWallet', 'CustomerWalletMaster'))
    OR (s.name = 'Finance' AND t.name = 'Transaction')
    OR (s.name = 'Support' AND t.name = 'Cases')
    OR (s.name = 'Common' AND t.name = 'PayeeAccounts')
ORDER BY s.name, t.name;

ALTER TABLE Member.Customer
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Member.CustomerWallet
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Member.CustomerWalletMaster
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Finance.[Transaction]
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Support.Cases
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Common.PayeeAccounts
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);

ALTER TABLE Master.Products
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);

SELECT
    SCHEMA_NAME(t.schema_id) AS SchemaName,
    t.name AS TableName,
    'ENABLED' AS ChangeTrackingStatus
FROM sys.change_tracking_tables ct
JOIN sys.tables t
    ON ct.object_id = t.object_id
ORDER BY SchemaName, TableName;

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = 'Reporting'
)
BEGIN
    EXEC('CREATE SCHEMA Reporting');
END

IF NOT EXISTS (
    SELECT 1
    FROM sys.tables t
    INNER JOIN sys.schemas s
        ON t.schema_id = s.schema_id
    WHERE t.name = 'SyncWatermark'
      AND s.name = 'Reporting'
)
BEGIN
    CREATE TABLE Reporting.SyncWatermark
    (
        SourceSchema NVARCHAR(128) NOT NULL,
        SourceTable NVARCHAR(128) NOT NULL,
        LastSyncVersion BIGINT NOT NULL,
        LastStartedDate DATETIME2 NULL,
        LastCompletedDate DATETIME2 NULL,
        LastStatus NVARCHAR(50) NULL,
        LastError NVARCHAR(MAX) NULL,

        CONSTRAINT PK_SyncWatermark
            PRIMARY KEY (SourceSchema, SourceTable)
    );
END

INSERT INTO Reporting.SyncWatermark
(
    SourceSchema,
    SourceTable,
    LastSyncVersion,
    LastStatus
)
SELECT v.SourceSchema,
       v.SourceTable,
       v.LastSyncVersion,
       v.LastStatus
FROM
(
    VALUES
        ('Member',  'Customer',             0, 'Pending'),
        ('Member',  'CustomerWallet',       0, 'Pending'),
        ('Member',  'CustomerWalletMaster', 0, 'Pending'),
        ('Finance', 'Transaction',          0, 'Pending'),
        ('Support', 'Cases',                0, 'Pending'),
        ('Common',  'PayeeAccounts',        0, 'Pending')
) v(SourceSchema, SourceTable, LastSyncVersion, LastStatus)
WHERE NOT EXISTS
(
    SELECT 1
    FROM Reporting.SyncWatermark sw
    WHERE sw.SourceSchema = v.SourceSchema
      AND sw.SourceTable = v.SourceTable
);



IF NOT EXISTS
(
    SELECT 1
    FROM sys.tables AS t
    JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id
    WHERE t.name = 'CustomerAssets'
      AND s.name = 'Reporting'
)
BEGIN
    CREATE TABLE Reporting.CustomerAssets
    (
        Id UNIQUEIDENTIFIER NOT NULL,
        CustomerId UNIQUEIDENTIFIER NOT NULL,
        WalletId UNIQUEIDENTIFIER NOT NULL,
        SourceRecordId UNIQUEIDENTIFIER NOT NULL,
        Type NVARCHAR(50) NOT NULL,
        CurrencyCode NVARCHAR(20) NULL,
        CurrencyType NVARCHAR(20) NULL,
        Network NVARCHAR(20) NULL,
        AppName NVARCHAR(20) NULL,
        State NVARCHAR(100) NULL,
        Balance DECIMAL(38,18) NOT NULL,
        CreatedDate DATETIME2 NOT NULL,
        ModifiedDate DATETIME2 NOT NULL,
        CardType NVARCHAR(100) NULL,
        TotalUSDBalance DECIMAL(38,18) NOT NULL,
        Status INT NULL,

        CONSTRAINT PK_CustomerAssets
            PRIMARY KEY (Id)
    );
END;


IF NOT EXISTS
(
    SELECT 1
    FROM sys.tables AS t
    INNER JOIN sys.schemas AS s
        ON s.schema_id = t.schema_id
    WHERE t.name = 'AssetSummary'
      AND s.name = 'Reporting'
)
BEGIN
    CREATE TABLE Reporting.AssetSummary
    (
        Id UNIQUEIDENTIFIER NOT NULL,
        AssetType VARCHAR(20) NOT NULL,
        State VARCHAR(50) NULL,
        CurrencyCode VARCHAR(20) NULL,
        TotalCount INT NOT NULL,
        TotalBalance DECIMAL(38,18) NOT NULL,
        LastUpdatedDate DATETIME2 NOT NULL,
        TotalUSDBalance DECIMAL(38,18) NOT NULL,

        CONSTRAINT PK_AssetSummary
            PRIMARY KEY (Id)
    );
END;

-- Customers
IF NOT EXISTS
(
    SELECT 1
    FROM sys.tables t
    INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE t.name = 'Customers'
      AND s.name = 'Reporting'
)
BEGIN
    CREATE TABLE Reporting.Customers
    (
        Id UNIQUEIDENTIFIER NOT NULL,
        SourceRecordId UNIQUEIDENTIFIER NOT NULL,
        FullName NVARCHAR(250) NULL,
        AccountType NVARCHAR(50) NULL,
        State NVARCHAR(100) NULL,
        KYCState NVARCHAR(100) NULL,
        KycRemarks NVARCHAR(MAX) NULL,
        CreatedDate DATETIME2 NOT NULL,
        ModifiedDate DATETIME2 NOT NULL,
        ReferralCustomerId UNIQUEIDENTIFIER NULL,
        MembershipType NVARCHAR(100) NULL,

        CONSTRAINT PK_Customers
            PRIMARY KEY (Id)
    );
END;


-- Transactions
IF NOT EXISTS
(
    SELECT 1
    FROM sys.tables t
    INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE t.name = 'Transactions'
      AND s.name = 'Reporting'
)
BEGIN
    CREATE TABLE Reporting.Transactions
    (
        Id UNIQUEIDENTIFIER NOT NULL,
        SourceRecordId UNIQUEIDENTIFIER NOT NULL,
        CustomerId UNIQUEIDENTIFIER NULL,
        CustomerName NVARCHAR(250) NULL,
        TxDate DATETIME2 NULL,
        TxSource NVARCHAR(100) NULL,
        TxType NVARCHAR(100) NULL,
        TxSubType NVARCHAR(100) NULL,
        TxWallet NVARCHAR(100) NULL,
        TXActionType NVARCHAR(100) NULL,
        State NVARCHAR(100) NULL,
        Amount DECIMAL(18,8) NULL,
        CreatedDate DATETIME2 NOT NULL,
        ModifiedDate DATETIME2 NOT NULL,
        MerchantName NVARCHAR(250) NULL,
        TxWith NVARCHAR(50) NULL,
        TotalCommission DECIMAL(38,18) NULL,
        AmountInUSD DECIMAL(38,18) NULL,

        CONSTRAINT PK_Reporting_Transactions
            PRIMARY KEY (Id)
    );
END;


-- TransactionSummary
IF NOT EXISTS
(
    SELECT 1
    FROM sys.tables t
    INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE t.name = 'TransactionSummary'
      AND s.name = 'Reporting'
)
BEGIN
    CREATE TABLE Reporting.TransactionSummary
    (
        Id UNIQUEIDENTIFIER NOT NULL,
        TxSource NVARCHAR(100) NULL,
        TxType NVARCHAR(100) NULL,
        TxSubType NVARCHAR(100) NULL,
        TxWallet NVARCHAR(100) NULL,
        TXActionType NVARCHAR(200) NULL,
        State NVARCHAR(100) NULL,
        TransactionCount BIGINT NOT NULL,
        TotalAmount DECIMAL(18,8) NOT NULL,
        LastUpdatedDate DATETIME2 NOT NULL,
        TxWith NVARCHAR(50) NULL,
        AmountInUSD DECIMAL(38,18) NULL,

        CONSTRAINT PK_TransactionSummary
            PRIMARY KEY (Id)
    );
END;


-- Cases
IF NOT EXISTS
(
    SELECT 1
    FROM sys.tables t
    INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE t.name = 'Cases'
      AND s.name = 'Reporting'
)
BEGIN
    CREATE TABLE Reporting.Cases
    (
        CaseId UNIQUEIDENTIFIER NOT NULL,
        CustomerId UNIQUEIDENTIFIER NULL,
        CaseNumber NVARCHAR(100) NULL,
        State NVARCHAR(100) NULL,
        Type NVARCHAR(100) NULL,
        Reason NVARCHAR(500) NULL,
        CreatedDate DATETIME2 NULL,
        CreatedBy NVARCHAR(100) NULL,
        ModifiedDate DATETIME2 NULL,

        CONSTRAINT PK_Reporting_Cases
            PRIMARY KEY (CaseId)
    );
END;


-- PayeeAccounts
IF NOT EXISTS
(
    SELECT 1
    FROM sys.tables t
    INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE t.name = 'PayeeAccounts'
      AND s.name = 'Reporting'
)
BEGIN
    CREATE TABLE Reporting.PayeeAccounts
    (
        Id UNIQUEIDENTIFIER NOT NULL,
        CustomerId UNIQUEIDENTIFIER NULL,
        FavouriteName NVARCHAR(250) NULL,
        PaymentType NVARCHAR(100) NULL,

        CONSTRAINT PK_Reporting_PayeeAccounts
            PRIMARY KEY (Id)
    );
END;


-- KpiSummary
IF NOT EXISTS
(
    SELECT 1
    FROM sys.tables t
    INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE t.name = 'KpiSummary'
      AND s.name = 'Reporting'
)
BEGIN
    CREATE TABLE Reporting.KpiSummary
    (
        Id UNIQUEIDENTIFIER NOT NULL,
        Type NVARCHAR(50) NOT NULL,
        State NVARCHAR(100) NOT NULL,
        TotalCount BIGINT NOT NULL,
        LastUpdatedDate DATETIME2 NOT NULL,

        CONSTRAINT PK_KpiSummary
            PRIMARY KEY (Id)
    );
END;


-- KPITrend
IF NOT EXISTS
(
    SELECT 1
    FROM sys.tables t
    INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE t.name = 'KPITrend'
      AND s.name = 'Reporting'
)
BEGIN
    CREATE TABLE Reporting.KPITrend
    (
        Id UNIQUEIDENTIFIER NOT NULL,
        KPIType NVARCHAR(50) NOT NULL,
        TrendYear INT NOT NULL,
        TrendMonth INT NOT NULL,
        TrendMonthName VARCHAR(10) NOT NULL,
        TotalValue INT NOT NULL,
        CreatedDate DATETIME2 NOT NULL,

        CONSTRAINT PK_KPITrend
            PRIMARY KEY (Id)
    );
END;


-- SyncErrorLog
IF NOT EXISTS
(
    SELECT 1
    FROM sys.tables t
    INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE t.name = 'SyncErrorLog'
      AND s.name = 'Reporting'
)
BEGIN
    CREATE TABLE Reporting.SyncErrorLog
    (
        Id UNIQUEIDENTIFIER NOT NULL,
        ProcedureName NVARCHAR(200) NULL,
        ErrorNumber INT NULL,
        ErrorMessage NVARCHAR(MAX) NULL,
        ErrorLine INT NULL,
        ErrorProcedure NVARCHAR(200) NULL,
        ErrorDate DATETIME2 NULL,

        CONSTRAINT PK_SyncErrorLog
            PRIMARY KEY (Id)
    );
END;


SELECT 'Customer' AS TableName, COUNT(*) AS SourceCount FROM Member.Customer
UNION ALL
SELECT 'CustomerWallet', COUNT(*) FROM Member.CustomerWallet
UNION ALL
SELECT 'CustomerWalletMaster', COUNT(*) FROM Member.CustomerWalletMaster
UNION ALL
SELECT 'Transaction', COUNT(*) FROM Finance.[Transaction]
UNION ALL
SELECT 'Cases', COUNT(*) FROM Support.Cases
UNION ALL
SELECT 'PayeeAccounts', COUNT(*) FROM Common.PayeeAccounts;

--TRUNCATE Table Reporting.Customers
INSERT INTO Reporting.Customers
(
    Id,
    SourceRecordId,
    FullName,
    AccountType,
    State,
    KYCState,
    KycRemarks,
    CreatedDate,
    ModifiedDate,
    ReferralCustomerId,
    MembershipType
)
SELECT
    NEWID(),
    C.Id,
    C.FullName,
    C.AccountType,
    C.State,
    C.KYCState,
    C.KycRemarks,
    ISNULL(C.CreatedDate, SYSUTCDATETIME()),
    ISNULL(C.ModifiedDate, SYSUTCDATETIME()),
    C.ReferralCustomerId,
    C.MembershipType
FROM Member.Customer C
WHERE 
    (C.Role NOT IN ('Admin', 'Agent') OR C.Role IS NULL)
    AND C.Status IN (1, 2)
  AND NOT EXISTS
  (
      SELECT 1
      FROM Reporting.Customers R
      WHERE R.SourceRecordId = C.Id
  );

--SELECT * FROM Reporting.Customers

INSERT INTO Reporting.CustomerAssets
(
    Id,
    CustomerId,
    WalletId,
    SourceRecordId,
    Type,
    CurrencyCode,
    CurrencyType,
    Network,
    AppName,
    State,
    Balance,
    CreatedDate,
    ModifiedDate,
    CardType,
    TotalUSDBalance,
    Status
)
SELECT
    NEWID(),
    CW.CustomerId,
    CW.WalletId,
    CW.Id,
    ISNULL(CW.Type, 'Unknown'),
    ISNULL(CW.Currency, 'Unknown'),
    ISNULL(CW.CurrencyType, 'Unknown'),
    ISNULL(CW.Network, 'Unknown'),
    ISNULL(CW.AppName, 'Unknown'),
    ISNULL(CW.State, 'Unknown'),
    CASE
        WHEN CW.CurrencyType = 'Crypto' THEN ISNULL(CWM.Available, 0)
        ELSE ISNULL(CW.Amount, 0)
    END,
    ISNULL(CW.CreatedDate, SYSUTCDATETIME()),
    ISNULL(CW.ModifiedDate, SYSUTCDATETIME()),
    CW.CardType,
    0,
    CASE
        WHEN CW.CurrencyType = 'Crypto' THEN CWM.Status
        ELSE CW.Status
    END
FROM Member.CustomerWallet CW
INNER JOIN Member.CustomerWalletMaster CWM
    ON CWM.Id = CW.WalletId
WHERE NOT EXISTS
(
    SELECT 1
    FROM Reporting.CustomerAssets CA
    WHERE CA.SourceRecordId = CW.Id
);


SELECT
    (SELECT COUNT(*) FROM Member.CustomerWallet) AS SourceCount,
    (SELECT COUNT(*) FROM Reporting.CustomerAssets) AS ReportingCount;


IF EXISTS
(
    SELECT 1
    FROM Reporting.CustomerAssets
)
BEGIN
    UPDATE CA
    SET CA.TotalUSDBalance =
        CA.Balance *
        CASE
            WHEN CA.CurrencyType = 'Crypto'
                THEN ISNULL(R.Rate, 1)
            ELSE 1
        END
    FROM Reporting.CustomerAssets CA
    OUTER APPLY
    (
        SELECT TOP 1
            E.Rate
        FROM MarketData.ExchangeapiRates E
        WHERE E.FromCoin = CA.CurrencyCode
          AND E.ToCoin = 'USD'
        ORDER BY E.[Date] DESC
    ) R;
END;

ALTER TABLE Reporting.AssetSummary
ALTER COLUMN AssetType NVARCHAR(100) NOT NULL;


IF EXISTS
(
    SELECT 1
    FROM Reporting.CustomerAssets
)
BEGIN
    INSERT INTO Reporting.AssetSummary
    (
        Id,
        AssetType,
        State,
        CurrencyCode,
        TotalCount,
        TotalBalance,
        LastUpdatedDate,
        TotalUSDBalance
    )
    SELECT
        NEWID(),
        ISNULL(Type, 'Unknown'),
        ISNULL(State, 'Unknown'),
        ISNULL(CurrencyCode, 'Unknown'),
        COUNT(*),
        ISNULL(SUM(Balance), 0),
        SYSUTCDATETIME(),
        ISNULL(SUM(TotalUSDBalance), 0)
    FROM Reporting.CustomerAssets
    GROUP BY
        ISNULL(Type, 'Unknown'),
        ISNULL(State, 'Unknown'),
        ISNULL(CurrencyCode, 'Unknown');
END;


SELECT * FROM Reporting.AssetSummary

INSERT INTO Reporting.Transactions
(
    Id,
    SourceRecordId,
    CustomerId,
    CustomerName,
    TxDate,
    TxSource,
    TxType,
    TxSubType,
    TxWallet,
    TXActionType,
    State,
    Amount,
    CreatedDate,
    ModifiedDate,
    MerchantName,
    TxWith,
    TotalCommission,
    AmountInUSD
)
SELECT
    NEWID(),
    T.Id,
    T.CustomerId,
    C.FullName,
    T.TxDate,
    T.TxSource,
    T.TxType,
    T.TxSubType,
    T.TxWallet,
    T.TXActionType,
    T.State,
    T.Amount,
    ISNULL(T.CreatedDate, SYSUTCDATETIME()),
    ISNULL(T.ModifiedDate, SYSUTCDATETIME()),
    T.MerchantName,
    T.TxWith,
    T.TotalComission,
    0
FROM Finance.[Transaction] T
LEFT JOIN Member.Customer C
    ON T.CustomerId = C.Id
WHERE NOT EXISTS
(
    SELECT 1
    FROM Reporting.Transactions RT
    WHERE RT.SourceRecordId = T.Id
);


SELECT
    (SELECT COUNT(*) FROM Finance.[Transaction]) AS SourceCount,
    (SELECT COUNT(*) FROM Reporting.Transactions) AS ReportingCount;


IF EXISTS
(
    SELECT 1
    FROM Reporting.Transactions
)
BEGIN
    UPDATE T
    SET T.AmountInUSD =
        ISNULL(T.Amount, 0) *
        CASE
            WHEN T.TxWallet IS NULL
              OR T.TxWallet = ''
              OR T.TxWallet = 'USD'
                THEN 1
            ELSE ISNULL(R.Rate, 1)
        END
    FROM Reporting.Transactions T
    OUTER APPLY
    (
        SELECT TOP 1
            E.Rate
        FROM MarketData.ExchangeapiRates E
        WHERE E.FromCoin = T.TxWallet
          AND E.ToCoin = 'USD'
        ORDER BY E.[Date] DESC
    ) R;
END;


SELECT * FROM Reporting.Transactions

--TRUNCATE TABLE Reporting.TransactionSummary;

IF EXISTS
(
    SELECT 1
    FROM Reporting.Transactions
)
BEGIN
    INSERT INTO Reporting.TransactionSummary
    (
        Id,
        TxSource,
        TxType,
        TxSubType,
        TxWallet,
        TXActionType,
        State,
        TransactionCount,
        TotalAmount,
        LastUpdatedDate,
        TxWith,
        AmountInUSD
    )
    SELECT
        NEWID(),
        ISNULL(TxSource, 'Unknown'),
        ISNULL(TxType, 'Unknown'),
        ISNULL(TxSubType, 'Unknown'),
        ISNULL(TxWallet, 'Unknown'),
        ISNULL(TXActionType, 'Unknown'),
        ISNULL(State, 'Unknown'),
        COUNT_BIG(*),
        ISNULL(SUM(Amount), 0),
        SYSUTCDATETIME(),
        ISNULL(TxWith, 'Unknown'),
        ISNULL(SUM(AmountInUSD), 0)
    FROM Reporting.Transactions
    GROUP BY
        ISNULL(TxSource, 'Unknown'),
        ISNULL(TxType, 'Unknown'),
        ISNULL(TxSubType, 'Unknown'),
        ISNULL(TxWallet, 'Unknown'),
        ISNULL(TXActionType, 'Unknown'),
        ISNULL(State, 'Unknown'),
        ISNULL(TxWith, 'Unknown');
END;

--TRUNCATE TABLE Reporting.Cases
INSERT INTO Reporting.Cases
(
    CaseId,
    CustomerId,
    CaseNumber,
    State,
    Type,
    Reason,
    CreatedDate,
    CreatedBy,
    ModifiedDate
)
SELECT
    A.Id,
    A.CustomerId,
    A.CaseNumber,
    A.State,
    A.Type,
    A.Reason,
    A.CreatedDate,
    A.CreatedBy,
    A.ModifiedDate
FROM Support.Cases A
WHERE NOT EXISTS
(
    SELECT 1
    FROM Reporting.Cases RC
    WHERE RC.CaseId = A.Id
);

SELECT
    (SELECT COUNT(*) FROM Support.Cases) AS SourceCount,
    (SELECT COUNT(*) FROM Reporting.Cases) AS ReportingCount;


INSERT INTO Reporting.PayeeAccounts
(
    Id,
    CustomerId,
    FavouriteName,
    PaymentType
)
SELECT
    P.Id,
    P.CustomerId,
    P.FavouriteName,
    P.PaymentType
FROM Common.PayeeAccounts P
WHERE NOT EXISTS
(
    SELECT 1
    FROM Reporting.PayeeAccounts RP
    WHERE RP.Id = P.Id
);

SELECT
    s.name AS SchemaName,
    t.name AS TableName,
    CASE
        WHEN ct.object_id IS NOT NULL THEN 'Enabled'
        ELSE 'Disabled'
    END AS ChangeTrackingStatus
FROM sys.tables t
JOIN sys.schemas s
    ON s.schema_id = t.schema_id
LEFT JOIN sys.change_tracking_tables ct
    ON ct.object_id = t.object_id
WHERE
    (s.name = 'Member' AND t.name IN ('Customer','CustomerWallet','CustomerWalletMaster'))
    OR (s.name = 'Finance' AND t.name IN ('Transaction'))
    OR (s.name = 'Support' AND t.name IN ('Cases'))
ORDER BY s.name, t.name;


ALTER TABLE Reporting.Customers
ADD Reference NVARCHAR(250) NULL;

IF EXISTS
(
    SELECT 1
    FROM Reporting.Customers RC
    INNER JOIN Member.Customer C
        ON RC.SourceRecordId = C.Id
    WHERE C.Role <> 'Admin'
       OR C.Role IS NULL
)
BEGIN
    UPDATE RC
    SET RC.Reference = C.Reference
    FROM Reporting.Customers RC
    INNER JOIN Member.Customer C
        ON RC.SourceRecordId = C.Id
    WHERE C.Role <> 'Admin'
       OR C.Role IS NULL;
END;

IF COL_LENGTH('Reporting.Customers', 'Status') IS NULL
BEGIN
    ALTER TABLE Reporting.Customers
    ADD Status INT NULL;
END;
GO

UPDATE RC
SET RC.Status = C.Status
FROM Reporting.Customers RC
INNER JOIN Member.Customer C
    ON RC.SourceRecordId = C.Id

IF COL_LENGTH('Reporting.Customers', 'BusinessName') IS NULL
BEGIN
    ALTER TABLE Reporting.Customers
    ADD BusinessName NVARCHAR(250) NULL;
END;
GO

--UPDATE RC
--SET RC.BusinessName = C.BusinessName
--FROM Reporting.Customers RC
--INNER JOIN Member.Customer C
--    ON RC.SourceRecordId = C.Id;
--GO

CREATE OR ALTER PROCEDURE [Reporting].[usp_SyncCustomers]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LastVersion BIGINT;
    DECLARE @CurrentVersion BIGINT;

    BEGIN TRY

        SELECT @LastVersion = LastSyncVersion
        FROM Reporting.SyncWatermark
        WHERE SourceSchema = 'Member'
          AND SourceTable = 'Customer';

        SET @CurrentVersion = CHANGE_TRACKING_CURRENT_VERSION();

        IF @LastVersion IS NULL
            SET @LastVersion = 0;


        -------------------------------------------------------
        -- UPDATE Existing Customers
        -------------------------------------------------------
        UPDATE RC
        SET
            RC.FullName = C.FullName,
            RC.BusinessName = C.BusinessName,
            RC.AccountType = C.AccountType,
            RC.State = C.State,
            RC.KYCState = C.KYCState,
            RC.KycRemarks = C.KycRemarks,
            RC.ModifiedDate = ISNULL(C.ModifiedDate, SYSUTCDATETIME()),
            RC.ReferralCustomerId = C.ReferralCustomerId,
            RC.MembershipType = C.MembershipType,
            RC.Reference = C.Reference,
            RC.Status = C.Status

        FROM Reporting.Customers RC

        INNER JOIN Member.Customer C
            ON RC.SourceRecordId = C.Id

        INNER JOIN CHANGETABLE
        (
            CHANGES Member.Customer, @LastVersion
        ) CT
            ON CT.Id = C.Id

        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION = 'U'
          AND (C.Role NOT IN ('Admin', 'Agent') OR C.Role IS NULL);


        -------------------------------------------------------
        -- DELETE Customers Deleted From Source
        -------------------------------------------------------
        DELETE RC
        FROM Reporting.Customers RC

        INNER JOIN CHANGETABLE
        (
            CHANGES Member.Customer, @LastVersion
        ) CT
            ON RC.SourceRecordId = CT.Id

        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION = 'D';


        -------------------------------------------------------
        -- DELETE Admin / Agent Customers
        -------------------------------------------------------
        DELETE RC
        FROM Reporting.Customers RC

        INNER JOIN Member.Customer C
            ON RC.SourceRecordId = C.Id

        INNER JOIN CHANGETABLE
        (
            CHANGES Member.Customer, @LastVersion
        ) CT
            ON CT.Id = C.Id

        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION = 'U'
          AND C.Role IN ('Admin', 'Agent');


        -------------------------------------------------------
        -- INSERT New Customers
        -------------------------------------------------------
        INSERT INTO Reporting.Customers
        (
            Id,
            SourceRecordId,
            FullName,
            BusinessName,
            AccountType,
            State,
            KYCState,
            KycRemarks,
            CreatedDate,
            ModifiedDate,
            ReferralCustomerId,
            MembershipType,
            Reference,
            Status
        )
        SELECT
            NEWID(),
            C.Id,
            C.FullName,
            C.BusinessName,
            C.AccountType,
            C.State,
            C.KYCState,
            C.KycRemarks,
            ISNULL(C.CreatedDate, SYSUTCDATETIME()),
            ISNULL(C.ModifiedDate, SYSUTCDATETIME()),
            C.ReferralCustomerId,
            C.MembershipType,
            C.Reference,
            C.Status

        FROM Member.Customer C

        INNER JOIN CHANGETABLE
        (
            CHANGES Member.Customer, @LastVersion
        ) CT
            ON CT.Id = C.Id

        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION IN ('I', 'U')
          AND (C.Role NOT IN ('Admin', 'Agent') OR C.Role IS NULL)

          AND NOT EXISTS
          (
              SELECT 1
              FROM Reporting.Customers RC
              WHERE RC.SourceRecordId = C.Id
          );


        -------------------------------------------------------
        -- UPDATE Watermark
        -------------------------------------------------------
        UPDATE Reporting.SyncWatermark
        SET
            LastSyncVersion = @CurrentVersion,
            LastCompletedDate = SYSUTCDATETIME(),
            LastStatus = 'Success',
            LastError = NULL
        WHERE SourceSchema = 'Member'
          AND SourceTable = 'Customer';


    END TRY

    BEGIN CATCH

        INSERT INTO Reporting.SyncErrorLog
        (
            Id,
            ProcedureName,
            ErrorNumber,
            ErrorMessage,
            ErrorLine,
            ErrorProcedure,
            ErrorDate
        )
        VALUES
        (
            NEWID(),
            'Reporting.usp_SyncCustomers',
            ERROR_NUMBER(),
            ERROR_MESSAGE(),
            ERROR_LINE(),
            ERROR_PROCEDURE(),
            SYSUTCDATETIME()
        );

        UPDATE Reporting.SyncWatermark
        SET
            LastStatus = 'Failed',
            LastError = ERROR_MESSAGE()
        WHERE SourceSchema = 'Member'
          AND SourceTable = 'Customer';

        THROW;

    END CATCH
END;
GO

EXEC [Reporting].[usp_SyncCustomers]







Go
CREATE OR ALTER PROCEDURE [Reporting].[usp_RebuildKPITrend]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        BEGIN TRANSACTION;

        DELETE FROM Reporting.KPITrend;


        -------------------------------------------------------
        -- 1. Customer Monthly Trend
        -------------------------------------------------------
        INSERT INTO Reporting.KPITrend
        (
            Id,
            KPIType,
            TrendYear,
            TrendMonth,
            TrendMonthName,
            TotalValue,
            CreatedDate
        )
        SELECT
            NEWID(),
            'Customer',
            YEAR(C.CreatedDate),
            MONTH(C.CreatedDate),
            LEFT(DATENAME(MONTH, C.CreatedDate), 3),
            COUNT(*),
            SYSUTCDATETIME()
        FROM Member.Customer C
        WHERE C.CreatedDate IS NOT NULL
          AND (
                C.Role NOT IN ('Admin', 'Agent')
                OR C.Role IS NULL AND Status IN (1,2)
              )
        GROUP BY
            YEAR(C.CreatedDate),
            MONTH(C.CreatedDate),
            DATENAME(MONTH, C.CreatedDate);


        -------------------------------------------------------
        -- 2. Cases Monthly Trend
        -------------------------------------------------------
        INSERT INTO Reporting.KPITrend
        (
            Id,
            KPIType,
            TrendYear,
            TrendMonth,
            TrendMonthName,
            TotalValue,
            CreatedDate
        )
        SELECT
            NEWID(),
            'Cases',
            YEAR(C.CreatedDate),
            MONTH(C.CreatedDate),
            LEFT(DATENAME(MONTH, C.CreatedDate), 3),
            COUNT(*),
            SYSUTCDATETIME()
        FROM Support.Cases C
        WHERE C.CreatedDate IS NOT NULL
        GROUP BY
            YEAR(C.CreatedDate),
            MONTH(C.CreatedDate),
            DATENAME(MONTH, C.CreatedDate);


        -------------------------------------------------------
        -- 3. Bank Accounts Monthly Trend
        -------------------------------------------------------
        INSERT INTO Reporting.KPITrend
        (
            Id,
            KPIType,
            TrendYear,
            TrendMonth,
            TrendMonthName,
            TotalValue,
            CreatedDate
        )
        SELECT
            NEWID(),
            'BankAccounts',
            YEAR(C.CreatedDate),
            MONTH(C.CreatedDate),
            LEFT(DATENAME(MONTH, C.CreatedDate), 3),
            COUNT(*),
            SYSUTCDATETIME()
        FROM Member.CustomerWallet C
        WHERE C.Type = 'Banks'
          AND C.CreatedDate IS NOT NULL
        GROUP BY
            YEAR(C.CreatedDate),
            MONTH(C.CreatedDate),
            DATENAME(MONTH, C.CreatedDate);


        -------------------------------------------------------
        -- 4. Wallets Monthly Trend
        -------------------------------------------------------
        INSERT INTO Reporting.KPITrend
        (
            Id,
            KPIType,
            TrendYear,
            TrendMonth,
            TrendMonthName,
            TotalValue,
            CreatedDate
        )
        SELECT
            NEWID(),
            'Wallets',
            YEAR(C.CreatedDate),
            MONTH(C.CreatedDate),
            LEFT(DATENAME(MONTH, C.CreatedDate), 3),
            COUNT(*),
            SYSUTCDATETIME()
        FROM Member.CustomerWallet C
        WHERE C.AppName = 'Wallets'
          AND C.CreatedDate IS NOT NULL
        GROUP BY
            YEAR(C.CreatedDate),
            MONTH(C.CreatedDate),
            DATENAME(MONTH, C.CreatedDate);


        -------------------------------------------------------
        -- 5. Cards Monthly Trend
        -------------------------------------------------------
        INSERT INTO Reporting.KPITrend
        (
            Id,
            KPIType,
            TrendYear,
            TrendMonth,
            TrendMonthName,
            TotalValue,
            CreatedDate
        )
        SELECT
            NEWID(),
            'Cards',
            YEAR(C.CreatedDate),
            MONTH(C.CreatedDate),
            LEFT(DATENAME(MONTH, C.CreatedDate), 3),
            COUNT(*),
            SYSUTCDATETIME()
        FROM Member.CustomerWallet C
        WHERE C.Type = 'Cards'
          AND C.CreatedDate IS NOT NULL
        GROUP BY
            YEAR(C.CreatedDate),
            MONTH(C.CreatedDate),
            DATENAME(MONTH, C.CreatedDate);


        -------------------------------------------------------
        -- 6. Transactions Monthly Trend
        -------------------------------------------------------
        INSERT INTO Reporting.KPITrend
        (
            Id,
            KPIType,
            TrendYear,
            TrendMonth,
            TrendMonthName,
            TotalValue,
            CreatedDate
        )
        SELECT
            NEWID(),
            'Transactions',
            YEAR(T.CreatedDate),
            MONTH(T.CreatedDate),
            LEFT(DATENAME(MONTH, T.CreatedDate), 3),
            COUNT(*),
            SYSUTCDATETIME()
        FROM Finance.[Transaction] T
        WHERE T.CreatedDate IS NOT NULL
        GROUP BY
            YEAR(T.CreatedDate),
            MONTH(T.CreatedDate),
            DATENAME(MONTH, T.CreatedDate);


        COMMIT TRANSACTION;

    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH
END;
GO


EXEC Reporting.usp_RebuildKPITrend;

SELECT *
FROM Reporting.KPITrend
ORDER BY KPIType, TrendYear, TrendMonth;

Go
CREATE OR ALTER PROCEDURE Reporting.usp_RebuildKpiSummary
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE Reporting.KpiSummary;

    -------------------------------------------------------
    -- 1. Total Customers
    -------------------------------------------------------
    INSERT INTO Reporting.KpiSummary
    (
        Id,
        Type,
        State,
        TotalCount,
        LastUpdatedDate
    )
    SELECT 
        NEWID(),
        'Customer',
        'Total',
        COUNT(Id),
        SYSUTCDATETIME()
    FROM Member.Customer AS C
 WHERE   (C.Role NOT IN ('Admin', 'Agent') OR C.Role IS NULL)
   AND C.Status IN (1, 2)


    -------------------------------------------------------
    -- 2. Customer Status
    -------------------------------------------------------
    INSERT INTO Reporting.KpiSummary
    (
        Id,
        Type,
        State,
        TotalCount,
        LastUpdatedDate
    )
    SELECT
        NEWID(),
        'Customer',
        ISNULL(State, 'Unknown'),
        COUNT(Id),
        SYSUTCDATETIME()
    FROM Member.Customer AS C
 WHERE   (C.Role NOT IN ('Admin', 'Agent') OR C.Role IS NULL)
   AND C.Status IN (1, 2)
    GROUP BY
        ISNULL(State, 'Unknown');


    -------------------------------------------------------
    -- 3. KYC/KYB Status
    -------------------------------------------------------
    INSERT INTO Reporting.KpiSummary
    (
        Id,
        Type,
        State,
        TotalCount,
        LastUpdatedDate
    )
    SELECT
        NEWID(),
        'KYC/KYB',
        ISNULL(KYCState, 'Unknown'),
        COUNT(Id),
        SYSUTCDATETIME()
    FROM Member.Customer AS C
 WHERE   (C.Role NOT IN ('Admin', 'Agent') OR C.Role IS NULL)
   AND C.Status IN (1, 2)
    GROUP BY
        ISNULL(KYCState, 'Unknown');


    -------------------------------------------------------
    -- 4. Total Cases
    -------------------------------------------------------
    INSERT INTO Reporting.KpiSummary
    (
        Id,
        Type,
        State,
        TotalCount,
        LastUpdatedDate
    )
    SELECT
        NEWID(),
        'Cases',
        'Total',
        COUNT(Id),
        SYSUTCDATETIME()
    FROM Support.Cases;


    -------------------------------------------------------
    -- 5. Case Status
    -------------------------------------------------------
    INSERT INTO Reporting.KpiSummary
    (
        Id,
        Type,
        State,
        TotalCount,
        LastUpdatedDate
    )
    SELECT
        NEWID(),
        'Cases',
        ISNULL(State, 'Unknown'),
        COUNT(Id),
        SYSUTCDATETIME()
    FROM Support.Cases
    GROUP BY
        ISNULL(State, 'Unknown');


    -------------------------------------------------------
    -- 6. Customer By Country
    -------------------------------------------------------
    INSERT INTO Reporting.KpiSummary
    (
        Id,
        Type,
        State,
        TotalCount,
        LastUpdatedDate
    )
    SELECT
        NEWID(),
        'Country',
        ISNULL(Country, 'Unknown'),
        COUNT(*),
        SYSUTCDATETIME()
    FROM Member.Customer AS C
 WHERE   (C.Role NOT IN ('Admin', 'Agent') OR C.Role IS NULL)
   AND C.Status IN (1, 2)
    GROUP BY
        ISNULL(Country, 'Unknown');


    -------------------------------------------------------
    -- 7. Top Banks
    -------------------------------------------------------
    INSERT INTO Reporting.KpiSummary
    (
        Id,
        Type,
        State,
        TotalCount,
        LastUpdatedDate
    )
    SELECT
        NEWID(),
        'Bank',
        ISNULL(
            JSON_VALUE(BankDetails, '$.BankName'),
            'Unknown'
        ),
        COUNT(*),
        SYSUTCDATETIME()
    FROM Member.CustomerWallet
    WHERE BankDetails IS NOT NULL
    GROUP BY
        ISNULL(
            JSON_VALUE(BankDetails, '$.BankName'),
            'Unknown'
        );


    -------------------------------------------------------
    -- 8. Cards By Program
    -------------------------------------------------------
    INSERT INTO Reporting.KpiSummary
    (
        Id,
        Type,
        State,
        TotalCount,
        LastUpdatedDate
    )
    SELECT
        NEWID(),
        'CardProgram',
        ISNULL(B.Name, 'Unknown'),
        COUNT(A.Id),
        SYSUTCDATETIME()
    FROM Member.CustomerWallet A
    INNER JOIN Master.Products B
        ON B.Id = A.ProductId
    WHERE
        A.Type = 'Cards'
        AND B.Type = 'Cards'
        AND B.Status = 1
    GROUP BY
        ISNULL(B.Name, 'Unknown');


    -------------------------------------------------------
    -- 9. Total PayIn
    -------------------------------------------------------
    INSERT INTO Reporting.KpiSummary
    (
        Id,
        Type,
        State,
        TotalCount,
        LastUpdatedDate
    )
    SELECT
        NEWID(),
        'PayIn',
        'Total',
        COUNT(Id),
        SYSUTCDATETIME()
    FROM Master.Invoice;

   --INSERT INTO Reporting.KpiSummary
   -- (
   --     Id,
   --     Type,
   --     State,
   --     TotalCount,
   --     LastUpdatedDate
   -- )
   -- SELECT
   --     NEWID(),
   --     'PayIn',
   --     'Total',
   --     COUNT(Id),
   --     SYSUTCDATETIME()
   -- FROM [Member].[BillingInvoice];




    -------------------------------------------------------
    -- 10. PayIn Status
    -------------------------------------------------------
    INSERT INTO Reporting.KpiSummary
    (
        Id,
        Type,
        State,
        TotalCount,
        LastUpdatedDate
    )
    SELECT
        NEWID(),
        'PayIn',
        ISNULL(InvoiceState, 'Unknown'),
        COUNT(Id),
        SYSUTCDATETIME()
    FROM Master.Invoice
    GROUP BY
        ISNULL(InvoiceState, 'Unknown');

  --INSERT INTO Reporting.KpiSummary
  --  (
  --      Id,
  --      Type,
  --      State,
  --      TotalCount,
  --      LastUpdatedDate
  --  )
  --  SELECT
  --      NEWID(),
  --      'PayIn',
  --      ISNULL(PaymentStatus, 'Unknown'),
  --      COUNT(Id),
  --      SYSUTCDATETIME()
  --  FROM [Member].[BillingInvoice]
  --  GROUP BY
  --      ISNULL(PaymentStatus, 'Unknown');

    -------------------------------------------------------
    -- 11. Total PayOut
    -------------------------------------------------------
    INSERT INTO Reporting.KpiSummary
    (
        Id,
        Type,
        State,
        TotalCount,
        LastUpdatedDate
    )
    SELECT
        NEWID(),
        'PayOut',
        'Total',
        COUNT(Id),
        SYSUTCDATETIME()
    FROM Finance.[Transaction]
    WHERE TxType IN ('PayOut', 'CryptoPayOut');


    -------------------------------------------------------
    -- 12. PayOut Status
    -------------------------------------------------------
    INSERT INTO Reporting.KpiSummary
    (
        Id,
        Type,
        State,
        TotalCount,
        LastUpdatedDate
    )
    SELECT
        NEWID(),
        'PayOut',
        ISNULL(State, 'Unknown'),
        COUNT(Id),
        SYSUTCDATETIME()
    FROM Finance.[Transaction]
    WHERE TxType IN ('PayOut', 'CryptoPayOut')
    GROUP BY
        ISNULL(State, 'Unknown');

END;
GO


EXEC Reporting.usp_RebuildKpiSummary;

SELECT *
FROM Reporting.KpiSummary
ORDER BY Type, State;


SELECT
    SCHEMA_NAME(schema_id) AS SchemaName,
    name AS ProcedureName
FROM sys.procedures
WHERE schema_id = SCHEMA_ID('Reporting')
ORDER BY name;

IF COL_LENGTH('Reporting.CustomerAssets', 'AccNoOrCryptoAddress') IS NULL
BEGIN
    ALTER TABLE Reporting.CustomerAssets
    ADD AccNoOrCryptoAddress NVARCHAR(500) NULL;
END;
GO

--UPDATE CA
--SET CA.AccNoOrCryptoAddress = CW.AccNoOrCryptoAddress
--FROM Reporting.CustomerAssets CA
--INNER JOIN Member.CustomerWallet CW
--    ON CA.SourceRecordId = CW.Id;

IF COL_LENGTH('Reporting.CustomerAssets', 'WalletmasterStatus') IS NULL
BEGIN
    ALTER TABLE Reporting.CustomerAssets
    ADD WalletmasterStatus INT NULL;
END;
GO

UPDATE CA
SET CA.WalletmasterStatus = CWM.Status
FROM Reporting.CustomerAssets CA
INNER JOIN Member.CustomerWallet CW
    ON CA.SourceRecordId = CW.Id
LEFT JOIN Member.CustomerWalletMaster CWM
    ON CWM.Id = CW.WalletId;
GO



;WITH RankedCrypto AS
(
    SELECT
        CA.Id,
        CA.WalletId,
        ROW_NUMBER() OVER
        (
            PARTITION BY CA.WalletId
            ORDER BY CA.CreatedDate, CA.Id
        ) AS RN
    FROM Reporting.CustomerAssets CA
    WHERE CA.CurrencyType = 'Crypto'
)
UPDATE CA
SET CA.Balance =
    CASE
        WHEN R.RN = 1
            THEN ISNULL(CWM.Available, 0)
        ELSE 0
    END
FROM Reporting.CustomerAssets CA
INNER JOIN RankedCrypto R
    ON R.Id = CA.Id
INNER JOIN Member.CustomerWalletMaster CWM
    ON CWM.Id = CA.WalletId
WHERE CA.CurrencyType = 'Crypto';
GO

GO

CREATE OR ALTER PROCEDURE [Reporting].[usp_SyncCustomerAssets]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LastVersion BIGINT;
    DECLARE @CurrentVersion BIGINT;

    BEGIN TRY

        -------------------------------------------------------
        -- GET WATERMARK
        -------------------------------------------------------
        SELECT @LastVersion = LastSyncVersion
        FROM Reporting.SyncWatermark
        WHERE SourceSchema = 'Member'
          AND SourceTable = 'CustomerWallet';

        SET @CurrentVersion = CHANGE_TRACKING_CURRENT_VERSION();

        IF @LastVersion IS NULL
            SET @LastVersion = 0;

        -------------------------------------------------------
        -- DELETE REMOVED WALLETS
        -------------------------------------------------------
        DELETE CA
        FROM Reporting.CustomerAssets CA
        INNER JOIN CHANGETABLE
        (
            CHANGES Member.CustomerWallet, @LastVersion
        ) CT
            ON CA.SourceRecordId = CT.Id
        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION = 'D';

        -------------------------------------------------------
        -- UPDATE EXISTING RECORDS
        -------------------------------------------------------
        UPDATE CA
        SET
            CA.CustomerId = CW.CustomerId,
            CA.WalletId = CW.WalletId,
            CA.Type = ISNULL(CW.Type, 'Unknown'),
            CA.CurrencyCode = ISNULL(CW.Currency, 'Unknown'),
            CA.CurrencyType = ISNULL(CW.CurrencyType, 'Unknown'),
            CA.Network = ISNULL(CW.Network, 'Unknown'),
            CA.AppName = ISNULL(CW.AppName, 'Unknown'),
            CA.State = ISNULL(CW.State, 'Unknown'),
            CA.AccNoOrCryptoAddress = CW.AccNoOrCryptoAddress,

            -- Permanent duplicate-balance prevention
            CA.Balance =
                CASE
                    WHEN CW.CurrencyType = 'Crypto'
                    THEN
                        CASE
                            WHEN CW.Id =
                            (
                                SELECT TOP (1) CW2.Id
                                FROM Member.CustomerWallet CW2
                                WHERE CW2.WalletId = CW.WalletId
                                ORDER BY CW2.CreatedDate, CW2.Id
                            )
                            THEN ISNULL(CWM.Available, 0)
                            ELSE 0
                        END
                    ELSE ISNULL(CW.Amount, 0)
                END,

            CA.ModifiedDate =
                ISNULL(CW.ModifiedDate, SYSUTCDATETIME()),

            CA.CardType = CW.CardType,

            CA.Status =
                CASE
                    WHEN CW.CurrencyType = 'Crypto'
                        THEN CWM.Status
                    ELSE CW.Status
                END,

            CA.WalletmasterStatus = CWM.Status

        FROM Reporting.CustomerAssets CA
        INNER JOIN Member.CustomerWallet CW
            ON CA.SourceRecordId = CW.Id
        LEFT JOIN Member.CustomerWalletMaster CWM
            ON CWM.Id = CW.WalletId
        INNER JOIN CHANGETABLE
        (
            CHANGES Member.CustomerWallet, @LastVersion
        ) CT
            ON CT.Id = CW.Id
        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION = 'U';

        -------------------------------------------------------
        -- INSERT NEW RECORDS
        -------------------------------------------------------
        INSERT INTO Reporting.CustomerAssets
        (
            Id,
            CustomerId,
            WalletId,
            SourceRecordId,
            Type,
            CurrencyCode,
            CurrencyType,
            Network,
            AppName,
            State,
            AccNoOrCryptoAddress,
            Balance,
            CreatedDate,
            ModifiedDate,
            CardType,
            TotalUSDBalance,
            Status,
            WalletmasterStatus
        )
        SELECT
            NEWID(),
            CW.CustomerId,
            CW.WalletId,
            CW.Id,
            ISNULL(CW.Type, 'Unknown'),
            ISNULL(CW.Currency, 'Unknown'),
            ISNULL(CW.CurrencyType, 'Unknown'),
            ISNULL(CW.Network, 'Unknown'),
            ISNULL(CW.AppName, 'Unknown'),
            ISNULL(CW.State, 'Unknown'),
            CW.AccNoOrCryptoAddress,

            -- Permanent duplicate-balance prevention
            CASE
                WHEN CW.CurrencyType = 'Crypto'
                THEN
                    CASE
                        WHEN CW.Id =
                        (
                            SELECT TOP (1) CW2.Id
                            FROM Member.CustomerWallet CW2
                            WHERE CW2.WalletId = CW.WalletId
                            ORDER BY CW2.CreatedDate, CW2.Id
                        )
                        THEN ISNULL(CWM.Available, 0)
                        ELSE 0
                    END
                ELSE ISNULL(CW.Amount, 0)
            END,

            ISNULL(CW.CreatedDate, SYSUTCDATETIME()),
            ISNULL(CW.ModifiedDate, SYSUTCDATETIME()),
            CW.CardType,
            0,

            CASE
                WHEN CW.CurrencyType = 'Crypto'
                    THEN CWM.Status
                ELSE CW.Status
            END,

            CWM.Status

        FROM Member.CustomerWallet CW
        LEFT JOIN Member.CustomerWalletMaster CWM
            ON CWM.Id = CW.WalletId
        INNER JOIN CHANGETABLE
        (
            CHANGES Member.CustomerWallet, @LastVersion
        ) CT
            ON CT.Id = CW.Id
        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION = 'I'
          AND NOT EXISTS
          (
              SELECT 1
              FROM Reporting.CustomerAssets CA
              WHERE CA.SourceRecordId = CW.Id
          );

        -------------------------------------------------------
        -- REFRESH CRYPTO BALANCES PERMANENTLY
        -- Handles existing records and master balance changes
        -------------------------------------------------------
        ;WITH RankedCrypto AS
        (
            SELECT
                CA.Id,
                CA.WalletId,
                ROW_NUMBER() OVER
                (
                    PARTITION BY CA.WalletId
                    ORDER BY CW.CreatedDate, CW.Id
                ) AS RN
            FROM Reporting.CustomerAssets CA
            INNER JOIN Member.CustomerWallet CW
                ON CW.Id = CA.SourceRecordId
            WHERE CA.CurrencyType = 'Crypto'
        )
        UPDATE CA
        SET CA.Balance =
            CASE
                WHEN R.RN = 1
                    THEN ISNULL(CWM.Available, 0)
                ELSE 0
            END,
            CA.WalletmasterStatus = CWM.Status
        FROM Reporting.CustomerAssets CA
        INNER JOIN RankedCrypto R
            ON R.Id = CA.Id
        LEFT JOIN Member.CustomerWalletMaster CWM
            ON CWM.Id = R.WalletId;

        -------------------------------------------------------
        -- UPDATE WATERMARK
        -------------------------------------------------------
        UPDATE Reporting.SyncWatermark
        SET
            LastSyncVersion = @CurrentVersion,
            LastCompletedDate = SYSUTCDATETIME(),
            LastStatus = 'Success',
            LastError = NULL
        WHERE SourceSchema = 'Member'
          AND SourceTable = 'CustomerWallet';

    END TRY
    BEGIN CATCH

        INSERT INTO Reporting.SyncErrorLog
        (
            Id,
            ProcedureName,
            ErrorNumber,
            ErrorMessage,
            ErrorLine,
            ErrorProcedure,
            ErrorDate
        )
        VALUES
        (
            NEWID(),
            'Reporting.usp_SyncCustomerAssets',
            ERROR_NUMBER(),
            ERROR_MESSAGE(),
            ERROR_LINE(),
            ERROR_PROCEDURE(),
            SYSUTCDATETIME()
        );

        UPDATE Reporting.SyncWatermark
        SET
            LastStatus = 'Failed',
            LastError = ERROR_MESSAGE()
        WHERE SourceSchema = 'Member'
          AND SourceTable = 'CustomerWallet';

        THROW;
    END CATCH
END;
GO

EXEC Reporting.usp_SyncCustomerAssets;
GO


SELECT TOP 10 *
FROM Reporting.CustomerAssets
ORDER BY ModifiedDate DESC;

GO
CREATE OR ALTER PROCEDURE [Reporting].[usp_SyncCustomerWalletMaster]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LastVersion BIGINT;
    DECLARE @CurrentVersion BIGINT;

    BEGIN TRY

        SELECT @LastVersion = LastSyncVersion
        FROM Reporting.SyncWatermark
        WHERE SourceSchema = 'Member'
          AND SourceTable = 'CustomerWalletMaster';

        SET @CurrentVersion = CHANGE_TRACKING_CURRENT_VERSION();

        IF @LastVersion IS NULL
            SET @LastVersion = 0;

        -------------------------------------------------------
        -- UPDATE CustomerAssets
        -------------------------------------------------------
        UPDATE CA
        SET
            CA.Balance =
                CASE
                    WHEN CW.CurrencyType = 'Crypto'
                        THEN ISNULL(CWM.Available, 0)
                    ELSE CA.Balance
                END,
            CA.Status =
                CASE
                    WHEN CW.CurrencyType = 'Crypto'
                        THEN CWM.Status
                    ELSE CA.Status
                END,
            CA.ModifiedDate = SYSUTCDATETIME()
        FROM Reporting.CustomerAssets CA
        INNER JOIN Member.CustomerWallet CW
            ON CA.SourceRecordId = CW.Id
        INNER JOIN Member.CustomerWalletMaster CWM
            ON CWM.Id = CW.WalletId
        INNER JOIN CHANGETABLE
        (
            CHANGES Member.CustomerWalletMaster, @LastVersion
        ) CT
            ON CT.Id = CWM.Id
        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion;


        -------------------------------------------------------
        -- UPDATE WATERMARK
        -------------------------------------------------------
        UPDATE Reporting.SyncWatermark
        SET
            LastSyncVersion = @CurrentVersion,
            LastCompletedDate = SYSUTCDATETIME(),
            LastStatus = 'Success',
            LastError = NULL
        WHERE SourceSchema = 'Member'
          AND SourceTable = 'CustomerWalletMaster';

    END TRY

    BEGIN CATCH

        INSERT INTO Reporting.SyncErrorLog
        (
            Id,
            ProcedureName,
            ErrorNumber,
            ErrorMessage,
            ErrorLine,
            ErrorProcedure,
            ErrorDate
        )
        VALUES
        (
            NEWID(),
            'Reporting.usp_SyncCustomerWalletMaster',
            ERROR_NUMBER(),
            ERROR_MESSAGE(),
            ERROR_LINE(),
            ERROR_PROCEDURE(),
            SYSUTCDATETIME()
        );

        UPDATE Reporting.SyncWatermark
        SET
            LastStatus = 'Failed',
            LastError = ERROR_MESSAGE()
        WHERE SourceSchema = 'Member'
          AND SourceTable = 'CustomerWalletMaster';

        THROW;

    END CATCH
END;
GO

EXEC Reporting.usp_SyncCustomerWalletMaster;

GO
CREATE OR ALTER PROCEDURE [Reporting].[usp_RebuildTransactionSummary]
AS
BEGIN
    SET NOCOUNT ON;

    TRUNCATE TABLE Reporting.TransactionSummary;

    INSERT INTO Reporting.TransactionSummary
    (
        Id,
        TxSource,
        TxType,
        TxSubType,
        TxWallet,
        TXActionType,
        State,
        TransactionCount,
        TotalAmount,
        LastUpdatedDate,
        TxWith,
        AmountInUSD
    )
    SELECT
        NEWID(),
        ISNULL(TxSource, 'Unknown'),
        ISNULL(TxType, 'Unknown'),
        ISNULL(TxSubType, 'Unknown'),
        ISNULL(TxWallet, 'Unknown'),
        ISNULL(TXActionType, 'Unknown'),
        ISNULL(State, 'Unknown'),
        COUNT_BIG(*),
        ISNULL(SUM(Amount), 0),
        SYSUTCDATETIME(),
        ISNULL(TxWith, 'Unknown'),
        ISNULL(SUM(AmountInUSD), 0)
    FROM Reporting.Transactions
    GROUP BY
        ISNULL(TxSource, 'Unknown'),
        ISNULL(TxType, 'Unknown'),
        ISNULL(TxSubType, 'Unknown'),
        ISNULL(TxWallet, 'Unknown'),
        ISNULL(TXActionType, 'Unknown'),
        ISNULL(State, 'Unknown'),
        ISNULL(TxWith, 'Unknown');
END;
GO

EXEC [Reporting].[usp_RebuildTransactionSummary]
GO

CREATE OR ALTER PROCEDURE [Reporting].[usp_SyncTransactions]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LastVersion BIGINT;
    DECLARE @CurrentVersion BIGINT;

    BEGIN TRY

        SELECT @LastVersion = LastSyncVersion
        FROM Reporting.SyncWatermark
        WHERE SourceSchema = 'Finance'
          AND SourceTable = 'Transaction';

        SET @CurrentVersion = CHANGE_TRACKING_CURRENT_VERSION();

        IF @LastVersion IS NULL
            SET @LastVersion = 0;


        -------------------------------------------------------
        -- DELETE
        -------------------------------------------------------
        DELETE RT
        FROM Reporting.Transactions RT
        INNER JOIN CHANGETABLE
        (
            CHANGES Finance.[Transaction], @LastVersion
        ) CT
            ON RT.SourceRecordId = CT.Id
        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION = 'D';


        -------------------------------------------------------
        -- UPDATE
        -------------------------------------------------------
        UPDATE RT
        SET
            RT.CustomerId = T.CustomerId,
            RT.CustomerName = C.FullName,
            RT.TxDate = T.TxDate,
            RT.TxSource = T.TxSource,
            RT.TxType = T.TxType,
            RT.TxSubType = T.TxSubType,
            RT.TxWallet = T.TxWallet,
            RT.TXActionType = T.TXActionType,
            RT.State = T.State,
            RT.Amount = T.Amount,
            RT.ModifiedDate = ISNULL(T.ModifiedDate, SYSUTCDATETIME()),
            RT.MerchantName = T.MerchantName,
            RT.TxWith = T.TxWith,
            RT.TotalCommission = T.TotalComission
        FROM Reporting.Transactions RT
        INNER JOIN Finance.[Transaction] T
            ON RT.SourceRecordId = T.Id
        LEFT JOIN Member.Customer C
            ON T.CustomerId = C.Id
        INNER JOIN CHANGETABLE
        (
            CHANGES Finance.[Transaction], @LastVersion
        ) CT
            ON CT.Id = T.Id
        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION IN ('I','U');


        -------------------------------------------------------
        -- INSERT
        -------------------------------------------------------
        INSERT INTO Reporting.Transactions
        (
            Id,
            SourceRecordId,
            CustomerId,
            CustomerName,
            TxDate,
            TxSource,
            TxType,
            TxSubType,
            TxWallet,
            TXActionType,
            State,
            Amount,
            CreatedDate,
            ModifiedDate,
            MerchantName,
            TxWith,
            TotalCommission,
            AmountInUSD
        )
        SELECT
            NEWID(),
            T.Id,
            T.CustomerId,
            C.FullName,
            T.TxDate,
            T.TxSource,
            T.TxType,
            T.TxSubType,
            T.TxWallet,
            T.TXActionType,
            T.State,
            T.Amount,
            ISNULL(T.CreatedDate, SYSUTCDATETIME()),
            ISNULL(T.ModifiedDate, SYSUTCDATETIME()),
            T.MerchantName,
            T.TxWith,
            T.TotalComission,
            0
        FROM Finance.[Transaction] T
        LEFT JOIN Member.Customer C
            ON T.CustomerId = C.Id
        INNER JOIN CHANGETABLE
        (
            CHANGES Finance.[Transaction], @LastVersion
        ) CT
            ON CT.Id = T.Id
        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION IN ('I','U')
          AND NOT EXISTS
          (
              SELECT 1
              FROM Reporting.Transactions RT
              WHERE RT.SourceRecordId = T.Id
          );


        -------------------------------------------------------
        -- UPDATE USD AMOUNT
        -------------------------------------------------------
        UPDATE RT
        SET RT.AmountInUSD =
            ISNULL(RT.Amount, 0) *
            CASE
                WHEN RT.TxWallet IS NULL
                  OR RT.TxWallet = ''
                  OR RT.TxWallet = 'USD'
                    THEN 1
                ELSE ISNULL(R.Rate, 1)
            END
        FROM Reporting.Transactions RT
        OUTER APPLY
        (
            SELECT TOP 1 E.Rate
            FROM MarketData.ExchangeapiRates E
            WHERE E.FromCoin = RT.TxWallet
              AND E.ToCoin = 'USD'
            ORDER BY E.[Date] DESC
        ) R
        WHERE RT.SourceRecordId IN
        (
            SELECT CT.Id
            FROM CHANGETABLE
            (
                CHANGES Finance.[Transaction], @LastVersion
            ) CT
            WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
              AND CT.SYS_CHANGE_OPERATION IN ('I','U')
        );


        -------------------------------------------------------
        -- REBUILD TRANSACTION SUMMARY
        -------------------------------------------------------
        IF OBJECT_ID('Reporting.usp_RebuildTransactionSummary') IS NOT NULL
        BEGIN
            EXEC Reporting.usp_RebuildTransactionSummary;
        END;


        -------------------------------------------------------
        -- UPDATE WATERMARK
        -------------------------------------------------------
        UPDATE Reporting.SyncWatermark
        SET
            LastSyncVersion = @CurrentVersion,
            LastCompletedDate = SYSUTCDATETIME(),
            LastStatus = 'Success',
            LastError = NULL
        WHERE SourceSchema = 'Finance'
          AND SourceTable = 'Transaction';

    END TRY

    BEGIN CATCH

        INSERT INTO Reporting.SyncErrorLog
        (
            Id,
            ProcedureName,
            ErrorNumber,
            ErrorMessage,
            ErrorLine,
            ErrorProcedure,
            ErrorDate
        )
        VALUES
        (
            NEWID(),
            'Reporting.usp_SyncTransactions',
            ERROR_NUMBER(),
            ERROR_MESSAGE(),
            ERROR_LINE(),
            ERROR_PROCEDURE(),
            SYSUTCDATETIME()
        );

        UPDATE Reporting.SyncWatermark
        SET
            LastStatus = 'Failed',
            LastError = ERROR_MESSAGE()
        WHERE SourceSchema = 'Finance'
          AND SourceTable = 'Transaction';

        THROW;

    END CATCH
END;
GO

EXEC [Reporting].[usp_SyncTransactions]


SELECT
    SourceSchema,
    SourceTable,
    LastSyncVersion,
    LastStatus,
    LastCompletedDate,
    LastError
FROM Reporting.SyncWatermark
WHERE SourceSchema = 'Finance'
  AND SourceTable = 'Transaction';

GO
CREATE OR ALTER PROCEDURE [Reporting].[usp_SyncCases]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LastVersion BIGINT;
    DECLARE @CurrentVersion BIGINT;

    BEGIN TRY

        SELECT @LastVersion = LastSyncVersion
        FROM Reporting.SyncWatermark
        WHERE SourceSchema = 'Support'
          AND SourceTable = 'Cases';

        SET @CurrentVersion = CHANGE_TRACKING_CURRENT_VERSION();

        IF @LastVersion IS NULL
            SET @LastVersion = 0;


        -------------------------------------------------------
        -- DELETE
        -------------------------------------------------------
        DELETE RC
        FROM Reporting.Cases RC
        INNER JOIN CHANGETABLE
        (
            CHANGES Support.Cases, @LastVersion
        ) CT
            ON RC.CaseId = CT.Id
        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION = 'D';


        -------------------------------------------------------
        -- UPDATE
        -------------------------------------------------------
        UPDATE RC
        SET
            RC.CustomerId = C.CustomerId,
            RC.CaseNumber = C.CaseNumber,
            RC.State = C.State,
            RC.Type = C.Type,
            RC.Reason = C.Reason,
            RC.CreatedDate = C.CreatedDate,
            RC.CreatedBy = C.CreatedBy,
            RC.ModifiedDate = C.ModifiedDate
        FROM Reporting.Cases RC
        INNER JOIN Support.Cases C
            ON RC.CaseId = C.Id
        INNER JOIN CHANGETABLE
        (
            CHANGES Support.Cases, @LastVersion
        ) CT
            ON CT.Id = C.Id
        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION = 'U';


        -------------------------------------------------------
        -- INSERT
        -------------------------------------------------------
        INSERT INTO Reporting.Cases
        (
            CaseId,
            CustomerId,
            CaseNumber,
            State,
            Type,
            Reason,
            CreatedDate,
            CreatedBy,
            ModifiedDate
        )
        SELECT
            C.Id,
            C.CustomerId,
            C.CaseNumber,
            C.State,
            C.Type,
            C.Reason,
            C.CreatedDate,
            C.CreatedBy,
            C.ModifiedDate
        FROM Support.Cases C
        INNER JOIN CHANGETABLE
        (
            CHANGES Support.Cases, @LastVersion
        ) CT
            ON CT.Id = C.Id
        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION = 'I'
          AND NOT EXISTS
          (
              SELECT 1
              FROM Reporting.Cases RC
              WHERE RC.CaseId = C.Id
          );


        -------------------------------------------------------
        -- UPDATE WATERMARK
        -------------------------------------------------------
        UPDATE Reporting.SyncWatermark
        SET
            LastSyncVersion = @CurrentVersion,
            LastCompletedDate = SYSUTCDATETIME(),
            LastStatus = 'Success',
            LastError = NULL
        WHERE SourceSchema = 'Support'
          AND SourceTable = 'Cases';

    END TRY

    BEGIN CATCH

        INSERT INTO Reporting.SyncErrorLog
        (
            Id,
            ProcedureName,
            ErrorNumber,
            ErrorMessage,
            ErrorLine,
            ErrorProcedure,
            ErrorDate
        )
        VALUES
        (
            NEWID(),
            'Reporting.usp_SyncCases',
            ERROR_NUMBER(),
            ERROR_MESSAGE(),
            ERROR_LINE(),
            ERROR_PROCEDURE(),
            SYSUTCDATETIME()
        );

        UPDATE Reporting.SyncWatermark
        SET
            LastStatus = 'Failed',
            LastError = ERROR_MESSAGE()
        WHERE SourceSchema = 'Support'
          AND SourceTable = 'Cases';

        THROW;

    END CATCH
END;
GO

EXEC Reporting.usp_SyncCases;

SELECT
    SourceSchema,
    SourceTable,
    LastSyncVersion,
    LastStatus,
    LastCompletedDate,
    LastError
FROM Reporting.SyncWatermark
WHERE SourceSchema = 'Support'
  AND SourceTable = 'Cases';

GO
CREATE OR ALTER PROCEDURE [Reporting].[usp_SyncPayeeAccounts]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LastVersion BIGINT;
    DECLARE @CurrentVersion BIGINT;

    BEGIN TRY

        SELECT @LastVersion = LastSyncVersion
        FROM Reporting.SyncWatermark
        WHERE SourceSchema = 'Common'
          AND SourceTable = 'PayeeAccounts';

        SET @CurrentVersion = CHANGE_TRACKING_CURRENT_VERSION();

        IF @LastVersion IS NULL
            SET @LastVersion = 0;


        -------------------------------------------------------
        -- DELETE
        -------------------------------------------------------
        DELETE RP
        FROM Reporting.PayeeAccounts RP
        INNER JOIN CHANGETABLE
        (
            CHANGES Common.PayeeAccounts, @LastVersion
        ) CT
            ON RP.Id = CT.Id
        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION = 'D';


        -------------------------------------------------------
        -- UPDATE
        -------------------------------------------------------
        UPDATE RP
        SET
            RP.CustomerId = P.CustomerId,
            RP.FavouriteName = P.FavouriteName,
            RP.PaymentType = P.PaymentType
        FROM Reporting.PayeeAccounts RP
        INNER JOIN Common.PayeeAccounts P
            ON RP.Id = P.Id
        INNER JOIN CHANGETABLE
        (
            CHANGES Common.PayeeAccounts, @LastVersion
        ) CT
            ON CT.Id = P.Id
        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION = 'U';


        -------------------------------------------------------
        -- INSERT
        -------------------------------------------------------
        INSERT INTO Reporting.PayeeAccounts
        (
            Id,
            CustomerId,
            FavouriteName,
            PaymentType
        )
        SELECT
            P.Id,
            P.CustomerId,
            P.FavouriteName,
            P.PaymentType
        FROM Common.PayeeAccounts P
        INNER JOIN CHANGETABLE
        (
            CHANGES Common.PayeeAccounts, @LastVersion
        ) CT
            ON CT.Id = P.Id
        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION = 'I'
          AND NOT EXISTS
          (
              SELECT 1
              FROM Reporting.PayeeAccounts RP
              WHERE RP.Id = P.Id
          );


        -------------------------------------------------------
        -- UPDATE WATERMARK
        -------------------------------------------------------
        UPDATE Reporting.SyncWatermark
        SET
            LastSyncVersion = @CurrentVersion,
            LastCompletedDate = SYSUTCDATETIME(),
            LastStatus = 'Success',
            LastError = NULL
        WHERE SourceSchema = 'Common'
          AND SourceTable = 'PayeeAccounts';

    END TRY

    BEGIN CATCH

        INSERT INTO Reporting.SyncErrorLog
        (
            Id,
            ProcedureName,
            ErrorNumber,
            ErrorMessage,
            ErrorLine,
            ErrorProcedure,
            ErrorDate
        )
        VALUES
        (
            NEWID(),
            'Reporting.usp_SyncPayeeAccounts',
            ERROR_NUMBER(),
            ERROR_MESSAGE(),
            ERROR_LINE(),
            ERROR_PROCEDURE(),
            SYSUTCDATETIME()
        );

        UPDATE Reporting.SyncWatermark
        SET
            LastStatus = 'Failed',
            LastError = ERROR_MESSAGE()
        WHERE SourceSchema = 'Common'
          AND SourceTable = 'PayeeAccounts';

        THROW;

    END CATCH
END;
GO

EXEC Reporting.usp_SyncPayeeAccounts;

SELECT
    SourceSchema,
    SourceTable,
    LastSyncVersion,
    LastStatus,
    LastCompletedDate,
    LastError
FROM Reporting.SyncWatermark
WHERE SourceSchema = 'Common'
  AND SourceTable = 'PayeeAccounts';

GO
CREATE OR ALTER PROCEDURE [Reporting].[usp_RebuildAssetSummary]
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        TRUNCATE TABLE Reporting.AssetSummary;

        INSERT INTO Reporting.AssetSummary
        (
            Id,
            AssetType,
            State,
            CurrencyCode,
            TotalCount,
            TotalBalance,
            LastUpdatedDate,
            TotalUSDBalance
        )
        SELECT
            NEWID(),
            ISNULL(Type, 'Unknown'),
            ISNULL(State, 'Unknown'),
            ISNULL(CurrencyCode, 'Unknown'),
            COUNT(*),
            ISNULL(SUM(Balance), 0),
            SYSUTCDATETIME(),
            ISNULL(SUM(TotalUSDBalance), 0)
        FROM Reporting.CustomerAssets
        GROUP BY
            ISNULL(Type, 'Unknown'),
            ISNULL(State, 'Unknown'),
            ISNULL(CurrencyCode, 'Unknown');

    END TRY

    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

EXEC Reporting.usp_RebuildAssetSummary;


SELECT *
FROM Reporting.AssetSummary
ORDER BY AssetType, State, CurrencyCode;




SELECT
    servicename,
    status_desc,
    startup_type_desc
FROM sys.dm_server_services
WHERE servicename LIKE 'SQL Server Agent%';



SELECT
    SUSER_SNAME() AS LoginName,
    IS_SRVROLEMEMBER('sysadmin') AS IsSysAdmin,
    IS_SRVROLEMEMBER('securityadmin') AS IsSecurityAdmin,
    IS_SRVROLEMEMBER('serveradmin') AS IsServerAdmin;



    SELECT * FROM Member.Customer WHERE Role<> 'Admin' OR Role is null
    SELECT * FROM Reporting.Customers

SELECT * FROM Finance.[Transaction]

SELECT * FROM Reporting.Transactions



ALTER TABLE Reporting.Transactions
ADD Action Nvarchar(100) NULL;

--UPDATE RT
--SET RT.Action = FT.Action
--FROM Reporting.Transactions RT
--INNER JOIN Finance.[Transaction] FT
--    ON RT.SourceRecordId = FT.Id;



SELECT
    COUNT(*) AS TotalTransactions,
    COUNT(Action) AS ActionFilled,
    COUNT(*) - COUNT(Action) AS ActionNULL
FROM Reporting.Transactions;


SELECT * FROM Member.CustomerWallet 

SELECT * FROM Reporting.CustomerAssets


CREATE OR ALTER PROCEDURE [Reporting].[usp_SyncTransactions]
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LastVersion BIGINT;
    DECLARE @CurrentVersion BIGINT;

    BEGIN TRY

        -------------------------------------------------------
        -- GET LAST SYNC VERSION
        -------------------------------------------------------
        SELECT @LastVersion = LastSyncVersion
        FROM Reporting.SyncWatermark
        WHERE SourceSchema = 'Finance'
          AND SourceTable = 'Transaction';

        IF @LastVersion IS NULL
            SET @LastVersion = 0;

        -------------------------------------------------------
        -- CURRENT CHANGE TRACKING VERSION
        -------------------------------------------------------
        SET @CurrentVersion = CHANGE_TRACKING_CURRENT_VERSION();

        -------------------------------------------------------
        -- UPDATE STARTED DATE
        -------------------------------------------------------
        UPDATE Reporting.SyncWatermark
        SET
            LastStartedDate = SYSUTCDATETIME(),
            LastStatus = 'Running',
            LastError = NULL
        WHERE SourceSchema = 'Finance'
          AND SourceTable = 'Transaction';


        -------------------------------------------------------
        -- DELETE
        -------------------------------------------------------
        DELETE RT
        FROM Reporting.Transactions RT
        INNER JOIN CHANGETABLE
        (
            CHANGES Finance.[Transaction], @LastVersion
        ) CT
            ON RT.SourceRecordId = CT.Id
        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION = 'D';


        -------------------------------------------------------
        -- UPDATE
        -------------------------------------------------------
        UPDATE RT
        SET
            RT.CustomerId = T.CustomerId,
            RT.CustomerName = C.FullName,
            RT.TxDate = T.TxDate,
            RT.TxSource = T.TxSource,
            RT.TxType = T.TxType,
            RT.TxSubType = T.TxSubType,
            RT.TxWallet = T.TxWallet,
            RT.TXActionType = T.TXActionType,
            RT.Action = T.Action,
            RT.State = T.State,
            RT.Amount = T.Amount,
            RT.ModifiedDate = ISNULL(T.ModifiedDate, SYSUTCDATETIME()),
            RT.MerchantName = T.MerchantName,
            RT.TxWith = T.TxWith,
            RT.TotalCommission = T.TotalComission
        FROM Reporting.Transactions RT
        INNER JOIN Finance.[Transaction] T
            ON RT.SourceRecordId = T.Id
        LEFT JOIN Member.Customer C
            ON T.CustomerId = C.Id
        INNER JOIN CHANGETABLE
        (
            CHANGES Finance.[Transaction], @LastVersion
        ) CT
            ON CT.Id = T.Id
        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION IN ('I', 'U');


        -------------------------------------------------------
        -- INSERT
        -------------------------------------------------------
        INSERT INTO Reporting.Transactions
        (
            Id,
            SourceRecordId,
            CustomerId,
            CustomerName,
            TxDate,
            TxSource,
            TxType,
            TxSubType,
            TxWallet,
            TXActionType,
            Action,
            State,
            Amount,
            CreatedDate,
            ModifiedDate,
            MerchantName,
            TxWith,
            TotalCommission,
            AmountInUSD
        )
        SELECT
            NEWID(),
            T.Id,
            T.CustomerId,
            C.FullName,
            T.TxDate,
            T.TxSource,
            T.TxType,
            T.TxSubType,
            T.TxWallet,
            T.TXActionType,
            T.Action,
            T.State,
            T.Amount,
            ISNULL(T.CreatedDate, SYSUTCDATETIME()),
            ISNULL(T.ModifiedDate, SYSUTCDATETIME()),
            T.MerchantName,
            T.TxWith,
            T.TotalComission,
            0
        FROM Finance.[Transaction] T
        LEFT JOIN Member.Customer C
            ON T.CustomerId = C.Id
        INNER JOIN CHANGETABLE
        (
            CHANGES Finance.[Transaction], @LastVersion
        ) CT
            ON CT.Id = T.Id
        WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
          AND CT.SYS_CHANGE_OPERATION IN ('I', 'U')
          AND NOT EXISTS
          (
              SELECT 1
              FROM Reporting.Transactions RT
              WHERE RT.SourceRecordId = T.Id
          );


        -------------------------------------------------------
        -- UPDATE USD AMOUNT
        -------------------------------------------------------
        UPDATE RT
        SET RT.AmountInUSD =
            ISNULL(RT.Amount, 0) *
            CASE
                WHEN RT.TxWallet IS NULL
                  OR RT.TxWallet = ''
                  OR RT.TxWallet = 'USD'
                    THEN 1
                ELSE ISNULL(R.Rate, 1)
            END
        FROM Reporting.Transactions RT
        OUTER APPLY
        (
            SELECT TOP 1
                E.Rate
            FROM MarketData.ExchangeapiRates E
            WHERE E.FromCoin = RT.TxWallet
              AND E.ToCoin = 'USD'
            ORDER BY E.[Date] DESC
        ) R
        WHERE RT.SourceRecordId IN
        (
            SELECT CT.Id
            FROM CHANGETABLE
            (
                CHANGES Finance.[Transaction], @LastVersion
            ) CT
            WHERE CT.SYS_CHANGE_VERSION <= @CurrentVersion
              AND CT.SYS_CHANGE_OPERATION IN ('I', 'U')
        );


        -------------------------------------------------------
        -- REBUILD TRANSACTION SUMMARY
        -------------------------------------------------------
        IF OBJECT_ID('Reporting.usp_RebuildTransactionSummary') IS NOT NULL
        BEGIN
            EXEC Reporting.usp_RebuildTransactionSummary;
        END;


        -------------------------------------------------------
        -- UPDATE WATERMARK
        -------------------------------------------------------
        UPDATE Reporting.SyncWatermark
        SET
            LastSyncVersion = @CurrentVersion,
            LastCompletedDate = SYSUTCDATETIME(),
            LastStatus = 'Success',
            LastError = NULL
        WHERE SourceSchema = 'Finance'
          AND SourceTable = 'Transaction';

    END TRY

    BEGIN CATCH

        -------------------------------------------------------
        -- ERROR LOG
        -------------------------------------------------------
        INSERT INTO Reporting.SyncErrorLog
        (
            Id,
            ProcedureName,
            ErrorNumber,
            ErrorMessage,
            ErrorLine,
            ErrorProcedure,
            ErrorDate
        )
        VALUES
        (
            NEWID(),
            'Reporting.usp_SyncTransactions',
            ERROR_NUMBER(),
            ERROR_MESSAGE(),
            ERROR_LINE(),
            ERROR_PROCEDURE(),
            SYSUTCDATETIME()
        );

        -------------------------------------------------------
        -- UPDATE WATERMARK AS FAILED
        -------------------------------------------------------
        UPDATE Reporting.SyncWatermark
        SET
            LastStatus = 'Failed',
            LastError = ERROR_MESSAGE()
        WHERE SourceSchema = 'Finance'
          AND SourceTable = 'Transaction';

        THROW;

    END CATCH
END;
GO

EXEC [Reporting].[usp_SyncTransactions]

SELECT
    AssetType,
    COUNT(*) AS TotalCount
FROM Reporting.AssetSummary
WHERE AssetType IN ('Cards', 'Card')
GROUP BY AssetType;


SELECT
    SCHEMA_NAME(schema_id) AS SchemaName,
    name AS ProcedureName
FROM sys.procedures
WHERE name LIKE '%AssetSummary%';

--UPDATE Reporting.AssetSummary
--SET AssetType = 'Card'
--WHERE AssetType = 'Cards';


CREATE OR ALTER PROCEDURE [Reporting].[usp_RebuildAssetSummary]
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        TRUNCATE TABLE Reporting.AssetSummary;

        INSERT INTO Reporting.AssetSummary
        (
            Id,
            AssetType,
            State,
            CurrencyCode,
            TotalCount,
            TotalBalance,
            LastUpdatedDate,
            TotalUSDBalance
        )
        SELECT
            NEWID(),

            CASE
                WHEN Type = 'Banks' THEN 'Bank'
                WHEN Type = 'Cards' THEN 'Card'
                WHEN CurrencyType = 'Crypto' THEN 'Crypto'
                WHEN CurrencyType = 'Fiat' THEN 'Fiat'
                ELSE 'Other'
            END AS AssetType,

            ISNULL(State, 'Unknown') AS State,

            ISNULL(CurrencyCode, 'Unknown') AS CurrencyCode,

            COUNT(*) AS TotalCount,

            ISNULL(SUM(Balance), 0) AS TotalBalance,

            SYSUTCDATETIME() AS LastUpdatedDate,

            ISNULL(SUM(TotalUSDBalance), 0) AS TotalUSDBalance

        FROM Reporting.CustomerAssets

        GROUP BY
            CASE
                WHEN Type = 'Banks' THEN 'Bank'
                WHEN Type = 'Cards' THEN 'Card'
                WHEN CurrencyType = 'Crypto' THEN 'Crypto'
                WHEN CurrencyType = 'Fiat' THEN 'Fiat'
                ELSE 'Other'
            END,

            ISNULL(State, 'Unknown'),

            ISNULL(CurrencyCode, 'Unknown');

    END TRY

    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

EXEC [Reporting].[usp_RebuildAssetSummary]

SELECT *
FROM Reporting.AssetSummary
WHERE AssetType IN ('Bank', 'Banks');


SELECT *
FROM Reporting.AssetSummary
WHERE AssetType='Card'

EXEC Reporting.usp_RebuildAssetSummary;

SELECT
    AssetType,
    State,
    CurrencyCode,
    TotalCount,
    TotalBalance,
    TotalUSDBalance
FROM Reporting.AssetSummary
WHERE AssetType = 'Card'
ORDER BY State, CurrencyCode;

--CREATE OR ALTER PROCEDURE [Reporting].[usp_RebuildAssetSummary]
--AS
--BEGIN
--    SET NOCOUNT ON;
--    SET XACT_ABORT ON;

--    BEGIN TRY

--        BEGIN TRANSACTION;

--        -------------------------------------------------------
--        -- Latest Exchange Rates
--        -------------------------------------------------------
--        IF OBJECT_ID('tempdb..#LatestRates') IS NOT NULL
--            DROP TABLE #LatestRates;

--        SELECT
--            FromCoin,
--            ToCoin,
--            Rate
--        INTO #LatestRates
--        FROM
--        (
--            SELECT
--                FromCoin,
--                ToCoin,
--                Rate,
--                ROW_NUMBER() OVER
--                (
--                    PARTITION BY FromCoin, ToCoin
--                    ORDER BY [Date] DESC
--                ) AS RN
--            FROM MarketData.ExchangeapiRates
--        ) X
--        WHERE RN = 1;


--        -------------------------------------------------------
--        -- Clear Asset Summary
--        -------------------------------------------------------
--        TRUNCATE TABLE Reporting.AssetSummary;


--        -------------------------------------------------------
--        -- Customer Assets
--        -------------------------------------------------------
--        INSERT INTO Reporting.AssetSummary
--        (
--            Id,
--            AssetType,
--            State,
--            CurrencyCode,
--            TotalCount,
--            TotalBalance,
--            LastUpdatedDate,
--            TotalUSDBalance
--        )
--        SELECT
--            NEWID(),

--            CASE
--                ------------------------------------------------
--                -- Bank
--                ------------------------------------------------
--                WHEN CA.Type IN ('Banks', 'Bank')
--                    THEN 'Bank'

--                ------------------------------------------------
--                -- Card
--                -- IMPORTANT: Card checked before Fiat
--                ------------------------------------------------
--                WHEN CA.Type IN ('Cards', 'Card')
--                    THEN 'Card'

--                ------------------------------------------------
--                -- Crypto
--                ------------------------------------------------
--                WHEN CA.CurrencyType = 'Crypto'
--                    THEN 'Crypto'

--                ------------------------------------------------
--                -- Fiat
--                ------------------------------------------------
--                WHEN CA.CurrencyType = 'Fiat'
--                    THEN 'Fiat'

--                ELSE 'Other'
--            END AS AssetType,

--            ISNULL(CA.State, 'Unknown') AS State,

--            ISNULL(CA.CurrencyCode, 'Unknown') AS CurrencyCode,

--            COUNT(*) AS TotalCount,

--            ISNULL(SUM(CA.Balance), 0) AS TotalBalance,

--            SYSUTCDATETIME() AS LastUpdatedDate,

--            ISNULL
--            (
--                SUM
--                (
--                    ISNULL(CA.Balance, 0)
--                    * ISNULL(LR.Rate, 1)
--                ),
--                0
--            ) AS TotalUSDBalance

--        FROM Reporting.CustomerAssets CA

--        LEFT JOIN #LatestRates LR
--            ON LR.FromCoin = CA.CurrencyCode
--           AND LR.ToCoin = 'USD'

--        GROUP BY

--            CASE
--                WHEN CA.Type IN ('Banks', 'Bank')
--                    THEN 'Bank'

--                WHEN CA.Type IN ('Cards', 'Card')
--                    THEN 'Card'

--                WHEN CA.CurrencyType = 'Crypto'
--                    THEN 'Crypto'

--                WHEN CA.CurrencyType = 'Fiat'
--                    THEN 'Fiat'

--                ELSE 'Other'
--            END,

--            ISNULL(CA.State, 'Unknown'),

--            ISNULL(CA.CurrencyCode, 'Unknown');


--        -------------------------------------------------------
--        -- PayIn
--        -------------------------------------------------------
--        INSERT INTO Reporting.AssetSummary
--        (
--            Id,
--            AssetType,
--            State,
--            CurrencyCode,
--            TotalCount,
--            TotalBalance,
--            LastUpdatedDate,
--            TotalUSDBalance
--        )
--        SELECT
--            NEWID(),

--            'PayIn',

--            ISNULL(I.InvoiceState, 'Unknown'),

--            ISNULL(I.InvoiceCurrency, 'Unknown'),

--            COUNT(*),

--            ISNULL(SUM(I.Amount), 0),

--            SYSUTCDATETIME(),

--            ISNULL
--            (
--                SUM
--                (
--                    ISNULL(I.Amount, 0)
--                    * ISNULL(LR.Rate, 1)
--                ),
--                0
--            )

--        FROM Master.Invoice I

--        LEFT JOIN #LatestRates LR
--            ON LR.FromCoin = I.InvoiceCurrency
--           AND LR.ToCoin = 'USD'

--        GROUP BY
--            ISNULL(I.InvoiceState, 'Unknown'),
--            ISNULL(I.InvoiceCurrency, 'Unknown');


--        -------------------------------------------------------
--        -- PayOut
--        -------------------------------------------------------
--        INSERT INTO Reporting.AssetSummary
--        (
--            Id,
--            AssetType,
--            State,
--            CurrencyCode,
--            TotalCount,
--            TotalBalance,
--            LastUpdatedDate,
--            TotalUSDBalance
--        )
--        SELECT
--            NEWID(),

--            'PayOut',

--            ISNULL(T.State, 'Unknown'),

--            ISNULL(T.TxWallet, 'Unknown'),

--            COUNT(*),

--            ISNULL(SUM(T.Amount), 0),

--            SYSUTCDATETIME(),

--            ISNULL
--            (
--                SUM
--                (
--                    ISNULL(T.Amount, 0)
--                    * ISNULL(LR.Rate, 1)
--                ),
--                0
--            )

--        FROM Finance.[Transaction] T

--        LEFT JOIN #LatestRates LR
--            ON LR.FromCoin =
--                CASE
--                    WHEN T.TxWallet = 'Tether'
--                        THEN 'USDT'
--                    ELSE T.TxWallet
--                END
--           AND LR.ToCoin = 'USD'

--        WHERE T.TxType IN
--        (
--            'PayOut',
--            'CryptoPayOut'
--        )

--        GROUP BY
--            ISNULL(T.State, 'Unknown'),
--            ISNULL(T.TxWallet, 'Unknown');


--        -------------------------------------------------------
--        -- Cleanup
--        -------------------------------------------------------
--        DROP TABLE #LatestRates;

--        COMMIT TRANSACTION;

--    END TRY

--    BEGIN CATCH

--        IF @@TRANCOUNT > 0
--            ROLLBACK TRANSACTION;

--        IF OBJECT_ID('tempdb..#LatestRates') IS NOT NULL
--            DROP TABLE #LatestRates;

--        THROW;

--    END CATCH
--END;
--GO


CREATE OR ALTER PROCEDURE [Reporting].[usp_RebuildAssetSummary]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        BEGIN TRANSACTION;

        -------------------------------------------------------
        -- Latest Exchange Rates
        -------------------------------------------------------
        IF OBJECT_ID('tempdb..#LatestRates') IS NOT NULL
            DROP TABLE #LatestRates;

        SELECT
            FromCoin,
            ToCoin,
            Rate
        INTO #LatestRates
        FROM
        (
            SELECT
                FromCoin,
                ToCoin,
                Rate,
                ROW_NUMBER() OVER
                (
                    PARTITION BY FromCoin, ToCoin
                    ORDER BY [Date] DESC
                ) AS RN
            FROM MarketData.ExchangeapiRates
        ) X
        WHERE RN = 1;


        -------------------------------------------------------
        -- Clear Asset Summary
        -------------------------------------------------------
        TRUNCATE TABLE Reporting.AssetSummary;


        -------------------------------------------------------
        -- Customer Assets
        -------------------------------------------------------
        INSERT INTO Reporting.AssetSummary
        (
            Id,
            AssetType,
            State,
            CurrencyCode,
            TotalCount,
            TotalBalance,
            LastUpdatedDate,
            TotalUSDBalance
        )
        SELECT
            NEWID(),

            CASE
                ------------------------------------------------
                -- Bank
                ------------------------------------------------
                WHEN CA.Type IN ('Banks', 'Bank')
                    THEN 'Bank'

                ------------------------------------------------
                -- Card
                -- IMPORTANT: Card checked before Fiat
                ------------------------------------------------
                WHEN CA.Type IN ('Cards', 'Card')
                    THEN 'Card'

                ------------------------------------------------
                -- Crypto
                ------------------------------------------------
                WHEN CA.CurrencyType = 'Crypto'
                    THEN 'Crypto'

                ------------------------------------------------
                -- Fiat
                ------------------------------------------------
                WHEN CA.CurrencyType = 'Fiat'
                    THEN 'Fiat'

                ELSE 'Other'
            END AS AssetType,

            ISNULL(CA.State, 'Unknown') AS State,

            ISNULL(CA.CurrencyCode, 'Unknown') AS CurrencyCode,

            COUNT(*) AS TotalCount,

            ISNULL(SUM(CA.Balance), 0) AS TotalBalance,

            SYSUTCDATETIME() AS LastUpdatedDate,

            ISNULL
            (
                SUM
                (
                    ISNULL(CA.Balance, 0)
                    * ISNULL(LR.Rate, 1)
                ),
                0
            ) AS TotalUSDBalance

        FROM Reporting.CustomerAssets CA

        LEFT JOIN #LatestRates LR
            ON LR.FromCoin = CA.CurrencyCode
           AND LR.ToCoin = 'USD'

        GROUP BY

            CASE
                WHEN CA.Type IN ('Banks', 'Bank')
                    THEN 'Bank'

                WHEN CA.Type IN ('Cards', 'Card')
                    THEN 'Card'

                WHEN CA.CurrencyType = 'Crypto'
                    THEN 'Crypto'

                WHEN CA.CurrencyType = 'Fiat'
                    THEN 'Fiat'

                ELSE 'Other'
            END,

            ISNULL(CA.State, 'Unknown'),

            ISNULL(CA.CurrencyCode, 'Unknown');


        -------------------------------------------------------
        -- PayIn
        -------------------------------------------------------
        INSERT INTO Reporting.AssetSummary
        (
            Id,
            AssetType,
            State,
            CurrencyCode,
            TotalCount,
            TotalBalance,
            LastUpdatedDate,
            TotalUSDBalance
        )
        SELECT
            NEWID(),

            'PayIn',

            ISNULL(I.PaymentStatus, 'Unknown'),

            ISNULL(I.InvoiceCurrency, 'Unknown'),

            COUNT(*),

            ISNULL(SUM(I.TotalAmount), 0),

            SYSUTCDATETIME(),

            ISNULL
            (
                SUM
                (
                    ISNULL(I.TotalAmount, 0)
                    * ISNULL(LR.Rate, 1)
                ),
                0
            )

        FROM Member.BillingInvoice I

        LEFT JOIN #LatestRates LR
            ON LR.FromCoin = I.InvoiceCurrency
           AND LR.ToCoin = 'USD'

        GROUP BY
            ISNULL(I.PaymentStatus, 'Unknown'),
            ISNULL(I.InvoiceCurrency, 'Unknown');


        -------------------------------------------------------
        -- PayOut
        -------------------------------------------------------
        INSERT INTO Reporting.AssetSummary
        (
            Id,
            AssetType,
            State,
            CurrencyCode,
            TotalCount,
            TotalBalance,
            LastUpdatedDate,
            TotalUSDBalance
        )
        SELECT
            NEWID(),

            'PayOut',

            ISNULL(T.State, 'Unknown'),

            ISNULL(T.TxWallet, 'Unknown'),

            COUNT(*),

            ISNULL(SUM(T.Amount), 0),

            SYSUTCDATETIME(),

            ISNULL
            (
                SUM
                (
                    ISNULL(T.Amount, 0)
                    * ISNULL(LR.Rate, 1)
                ),
                0
            )

        FROM Finance.[Transaction] T

        LEFT JOIN #LatestRates LR
            ON LR.FromCoin =
                CASE
                    WHEN T.TxWallet = 'Tether'
                        THEN 'USDT'
                    ELSE T.TxWallet
                END
           AND LR.ToCoin = 'USD'

        WHERE T.TxType IN
        (
            'PayOut',
            'CryptoPayOut'
        )

        GROUP BY
            ISNULL(T.State, 'Unknown'),
            ISNULL(T.TxWallet, 'Unknown');


        -------------------------------------------------------
        -- Cleanup
        -------------------------------------------------------
        DROP TABLE #LatestRates;

        COMMIT TRANSACTION;

    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF OBJECT_ID('tempdb..#LatestRates') IS NOT NULL
            DROP TABLE #LatestRates;

        THROW;

    END CATCH
END;
GO
EXEC [Reporting].[usp_RebuildAssetSummary]

GO
CREATE OR ALTER PROCEDURE [Reporting].[usp_RefreshCustomerAssetsUSD]
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        UPDATE CA
        SET CA.TotalUSDBalance =
            ISNULL(CA.Balance, 0) *
            CASE
                WHEN CA.CurrencyType = 'Crypto'
                    THEN ISNULL(R.Rate, 1)
                ELSE 1
            END
        FROM Reporting.CustomerAssets CA
        OUTER APPLY
        (
            SELECT TOP 1
                E.Rate
            FROM MarketData.ExchangeapiRates E
            WHERE E.FromCoin = CA.CurrencyCode
              AND E.ToCoin = 'USD'
            ORDER BY E.[Date] DESC
        ) R;

    END TRY

    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

EXEC Reporting.usp_RefreshCustomerAssetsUSD;

GO
CREATE OR ALTER PROCEDURE [Reporting].[usp_SyncAllCustomerAssets]
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        -------------------------------------------------------
        -- 1. Customers
        -------------------------------------------------------
        EXEC Reporting.usp_SyncCustomers;


        -------------------------------------------------------
        -- 2. Customer Wallets
        -------------------------------------------------------
        EXEC Reporting.usp_SyncCustomerAssets;


        -------------------------------------------------------
        -- 3. Customer Wallet Master
        -------------------------------------------------------
        EXEC Reporting.usp_SyncCustomerWalletMaster;


        -------------------------------------------------------
        -- 4. Transactions
        -------------------------------------------------------
        EXEC Reporting.usp_SyncTransactions;


        -------------------------------------------------------
        -- 5. Cases
        -------------------------------------------------------
        EXEC Reporting.usp_SyncCases;


        -------------------------------------------------------
        -- 6. Payee Accounts
        -------------------------------------------------------
        EXEC Reporting.usp_SyncPayeeAccounts;


        -------------------------------------------------------
        -- 7. Refresh Customer Asset USD Values
        -------------------------------------------------------
        EXEC Reporting.usp_RefreshCustomerAssetsUSD;


        -------------------------------------------------------
        -- 8. Rebuild Asset Summary
        -------------------------------------------------------
        EXEC Reporting.usp_RebuildAssetSummary;


        -------------------------------------------------------
        -- 9. Rebuild Transaction Summary
        -------------------------------------------------------
        EXEC Reporting.usp_RebuildTransactionSummary;


        -------------------------------------------------------
        -- 10. Rebuild KPI Summary
        -------------------------------------------------------
        EXEC Reporting.usp_RebuildKpiSummary;


        -------------------------------------------------------
        -- 11. Rebuild KPI Trend
        -------------------------------------------------------
        EXEC Reporting.usp_RebuildKPITrend;

    END TRY

    BEGIN CATCH

        THROW;

    END CATCH
END;
GO

EXEC [Reporting].[usp_SyncAllCustomerAssets]

select * from Member.CustomerUsers



SELECT DISTINCT A.ProductId,B.Id FROM Member.CustomerWallet as a
inner join Master.products as b on a.ProductId=B.Id
Where a.Type='Cards' and B.Type='Cards' AND b.Status=1
 
 
ALTER TABLE Master.Products
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);


INSERT INTO Reporting.SyncWatermark
(
    SourceSchema,
    SourceTable,
    LastSyncVersion,
    LastStatus
)
SELECT
    'Master',
    'Products',
    0,
    'Pending'
WHERE NOT EXISTS
(
    SELECT 1
    FROM Reporting.SyncWatermark
    WHERE SourceSchema = 'Master'
      AND SourceTable = 'Products'
);
GO


 SELECT * FROM Master.Products 
 WHERE Type='Cards' and Status=1

 
 SELECT Id,Type,Provider,Name,CurrencyType,CardType,State,Status FROM Master.Products

CREATE TABLE Reporting.Products
(
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY
        DEFAULT NEWID(),

    SourceRecordId UNIQUEIDENTIFIER NOT NULL,

    Type NVARCHAR(100) NULL,
    Provider NVARCHAR(200) NULL,
    Name NVARCHAR(250) NULL,
    CurrencyType NVARCHAR(100) NULL,
    CardType NVARCHAR(100) NULL,
    State NVARCHAR(100) NULL,
    Status INT NULL,

    CreatedDate DATETIME2 NULL,

    LastUpdatedDate DATETIME2 NOT NULL
        DEFAULT SYSUTCDATETIME(),

    CONSTRAINT UQ_Reporting_Products_SourceRecordId
        UNIQUE (SourceRecordId)
);
GO


INSERT INTO Reporting.Products
(
    Id,
    SourceRecordId,
    Type,
    Provider,
    Name,
    CurrencyType,
    CardType,
    State,
    Status,
    CreatedDate,
    LastUpdatedDate
)
SELECT
    NEWID(),
    P.Id,
    P.Type,
    P.Provider,
    P.Name,
    P.CurrencyType,
    P.CardType,
    P.State,
    P.Status,
    P.CreatedDate,
    SYSUTCDATETIME()
FROM Master.Products AS P
WHERE NOT EXISTS
(
    SELECT 1
    FROM Reporting.Products AS RP
    WHERE RP.SourceRecordId = P.Id
);
GO

SELECT * FROM Reporting.SyncWatermark


GO

CREATE OR ALTER PROCEDURE [Reporting].[usp_SyncProducts]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @StartedAt DATETIME2 = SYSUTCDATETIME();

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Update watermark status
        UPDATE Reporting.SyncWatermark
        SET
            LastStartedDate = @StartedAt,
            LastStatus = 'Running',
            LastError = NULL
        WHERE SourceSchema = 'Master'
          AND SourceTable = 'Products';

        -- Update existing products
        UPDATE RP
        SET
            RP.Type = P.Type,
            RP.Provider = P.Provider,
            RP.Name = P.Name,
            RP.CurrencyType = P.CurrencyType,
            RP.CardType = P.CardType,
            RP.State = P.State,
            RP.Status = P.Status,
            RP.CreatedDate = P.CreatedDate,
            RP.LastUpdatedDate = SYSUTCDATETIME()
        FROM Reporting.Products AS RP
        INNER JOIN Master.Products AS P
            ON RP.SourceRecordId = P.Id;

        -- Insert new products
        INSERT INTO Reporting.Products
        (
            Id,
            SourceRecordId,
            Type,
            Provider,
            Name,
            CurrencyType,
            CardType,
            State,
            Status,
            CreatedDate,
            LastUpdatedDate
        )
        SELECT
            NEWID(),
            P.Id,
            P.Type,
            P.Provider,
            P.Name,
            P.CurrencyType,
            P.CardType,
            P.State,
            P.Status,
            P.CreatedDate,
            SYSUTCDATETIME()
        FROM Master.Products AS P
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM Reporting.Products AS RP
            WHERE RP.SourceRecordId = P.Id
        );

        -- Delete products removed from source
        DELETE RP
        FROM Reporting.Products AS RP
        WHERE NOT EXISTS
        (
            SELECT 1
            FROM Master.Products AS P
            WHERE P.Id = RP.SourceRecordId
        );

        -- Mark sync successful
        UPDATE Reporting.SyncWatermark
        SET
            LastCompletedDate = SYSUTCDATETIME(),
            LastStatus = 'Success',
            LastError = NULL
        WHERE SourceSchema = 'Master'
          AND SourceTable = 'Products';

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        UPDATE Reporting.SyncWatermark
        SET
            LastStatus = 'Failed',
            LastError = ERROR_MESSAGE()
        WHERE SourceSchema = 'Master'
          AND SourceTable = 'Products';

        INSERT INTO Reporting.SyncErrorLog
        (
            ProcedureName,
            ErrorNumber,
            ErrorMessage,
            ErrorLine,
            ErrorProcedure,
            ErrorDate
        )
        VALUES
        (
            'Reporting.usp_SyncProducts',
            ERROR_NUMBER(),
            ERROR_MESSAGE(),
            ERROR_LINE(),
            ERROR_PROCEDURE(),
            SYSUTCDATETIME()
        );

        THROW;
    END CATCH
END;
GO

EXEC [Reporting].[usp_SyncProducts]





EXEC [Reporting].[usp_SyncAllCustomerAssets]

select * from [Member].[BillingInvoice]

SELECT * FROM Master.Invoice

ALTER TABLE [Member].[BillingInvoice]
ENABLE CHANGE_TRACKING
WITH (TRACK_COLUMNS_UPDATED = ON);




EXEC [Reporting].[usp_RebuildAssetSummary]

CREATE OR ALTER PROCEDURE [Reporting].[usp_RebuildAssetSummary]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        BEGIN TRANSACTION;

        -------------------------------------------------------
        -- Latest Exchange Rates
        -------------------------------------------------------
        IF OBJECT_ID('tempdb..#LatestRates') IS NOT NULL
            DROP TABLE #LatestRates;

        SELECT
            FromCoin,
            ToCoin,
            Rate
        INTO #LatestRates
        FROM
        (
            SELECT
                FromCoin,
                ToCoin,
                Rate,
                ROW_NUMBER() OVER
                (
                    PARTITION BY FromCoin, ToCoin
                    ORDER BY [Date] DESC
                ) AS RN
            FROM MarketData.ExchangeapiRates
        ) X
        WHERE RN = 1;


        -------------------------------------------------------
        -- Clear Asset Summary
        -------------------------------------------------------
        TRUNCATE TABLE Reporting.AssetSummary;


        -------------------------------------------------------
        -- Customer Assets
        -------------------------------------------------------
        INSERT INTO Reporting.AssetSummary
        (
            Id,
            AssetType,
            State,
            CurrencyCode,
            TotalCount,
            TotalBalance,
            LastUpdatedDate,
            TotalUSDBalance
        )
        SELECT
            NEWID(),

            CASE
                ------------------------------------------------
                -- Bank
                ------------------------------------------------
                WHEN CA.Type IN ('Banks', 'Bank')
                    THEN 'Bank'

                ------------------------------------------------
                -- Card
                -- IMPORTANT: Card checked before Fiat
                ------------------------------------------------
                WHEN CA.Type IN ('Cards', 'Card')
                    THEN 'Card'

                ------------------------------------------------
                -- Crypto
                ------------------------------------------------
                WHEN CA.CurrencyType = 'Crypto'
                    THEN 'Crypto'

                ------------------------------------------------
                -- Fiat
                ------------------------------------------------
                WHEN CA.CurrencyType = 'Fiat'
                    THEN 'Fiat'

                ELSE 'Other'
            END AS AssetType,

            ISNULL(CA.State, 'Unknown') AS State,

            ISNULL(CA.CurrencyCode, 'Unknown') AS CurrencyCode,

            COUNT(*) AS TotalCount,

            ISNULL(SUM(CA.Balance), 0) AS TotalBalance,

            SYSUTCDATETIME() AS LastUpdatedDate,

            ISNULL
            (
                SUM
                (
                    ISNULL(CA.Balance, 0)
                    * ISNULL(LR.Rate, 1)
                ),
                0
            ) AS TotalUSDBalance

        FROM Reporting.CustomerAssets CA

        LEFT JOIN #LatestRates LR
            ON LR.FromCoin = CA.CurrencyCode
           AND LR.ToCoin = 'USD'

        GROUP BY

            CASE
                WHEN CA.Type IN ('Banks', 'Bank')
                    THEN 'Bank'

                WHEN CA.Type IN ('Cards', 'Card')
                    THEN 'Card'

                WHEN CA.CurrencyType = 'Crypto'
                    THEN 'Crypto'

                WHEN CA.CurrencyType = 'Fiat'
                    THEN 'Fiat'

                ELSE 'Other'
            END,

            ISNULL(CA.State, 'Unknown'),

            ISNULL(CA.CurrencyCode, 'Unknown');


        -------------------------------------------------------
        -- PayIn
        -------------------------------------------------------
        INSERT INTO Reporting.AssetSummary
        (
            Id,
            AssetType,
            State,
            CurrencyCode,
            TotalCount,
            TotalBalance,
            LastUpdatedDate,
            TotalUSDBalance
        )
        SELECT
            NEWID(),

            'PayIn',

            ISNULL(I.PaymentStatus, 'Unknown'),

            ISNULL(I.InvoiceCurrency, 'Unknown'),

            COUNT(*),

            ISNULL(SUM(I.TotalAmount), 0),

            SYSUTCDATETIME(),

            ISNULL
            (
                SUM
                (
                    ISNULL(I.TotalAmount, 0)
                    * ISNULL(LR.Rate, 1)
                ),
                0
            )

        FROM Member.BillingInvoice I

        LEFT JOIN #LatestRates LR
            ON LR.FromCoin = I.InvoiceCurrency
           AND LR.ToCoin = 'USD'

        GROUP BY
            ISNULL(I.PaymentStatus, 'Unknown'),
            ISNULL(I.InvoiceCurrency, 'Unknown');


        -------------------------------------------------------
        -- PayOut
        -------------------------------------------------------
        INSERT INTO Reporting.AssetSummary
        (
            Id,
            AssetType,
            State,
            CurrencyCode,
            TotalCount,
            TotalBalance,
            LastUpdatedDate,
            TotalUSDBalance
        )
        SELECT
            NEWID(),

            'PayOut',

            ISNULL(T.State, 'Unknown'),

            ISNULL(T.TxWallet, 'Unknown'),

            COUNT(*),

            ISNULL(SUM(T.Amount), 0),

            SYSUTCDATETIME(),

            ISNULL
            (
                SUM
                (
                    ISNULL(T.Amount, 0)
                    * ISNULL(LR.Rate, 1)
                ),
                0
            )

        FROM Finance.[Transaction] T

        LEFT JOIN #LatestRates LR
            ON LR.FromCoin =
                CASE
                    WHEN T.TxWallet = 'Tether'
                        THEN 'USDT'
                    ELSE T.TxWallet
                END
           AND LR.ToCoin = 'USD'

        WHERE T.TxType IN
        (
            'PayOut',
            'CryptoPayOut'
        )

        GROUP BY
            ISNULL(T.State, 'Unknown'),
            ISNULL(T.TxWallet, 'Unknown');


        -------------------------------------------------------
        -- Cleanup
        -------------------------------------------------------
        DROP TABLE #LatestRates;

        COMMIT TRANSACTION;

    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF OBJECT_ID('tempdb..#LatestRates') IS NOT NULL
            DROP TABLE #LatestRates;

        THROW;

    END CATCH
END;
GO

EXEC [Reporting].[usp_RebuildAssetSummary]




GO
CREATE OR ALTER PROCEDURE [Reporting].[usp_SyncAllCustomerAssets]
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        -------------------------------------------------------
        -- 1. Customers
        -------------------------------------------------------
        EXEC Reporting.usp_SyncCustomers;


        -------------------------------------------------------
        -- 2. Customer Wallets
        -------------------------------------------------------
        EXEC Reporting.usp_SyncCustomerAssets;


        -------------------------------------------------------
        -- 3. Customer Wallet Master
        -------------------------------------------------------
        EXEC Reporting.usp_SyncCustomerWalletMaster;


        -------------------------------------------------------
        -- 4. Transactions
        -------------------------------------------------------
        EXEC Reporting.usp_SyncTransactions;


        -------------------------------------------------------
        -- 5. Cases
        -------------------------------------------------------
        EXEC Reporting.usp_SyncCases;


        -------------------------------------------------------
        -- 6. Payee Accounts
        -------------------------------------------------------
        EXEC Reporting.usp_SyncPayeeAccounts;


        -------------------------------------------------------
        -- 7. Refresh Customer Asset USD Values
        -------------------------------------------------------
        EXEC Reporting.usp_RefreshCustomerAssetsUSD;


        -------------------------------------------------------
        -- 8. Rebuild Asset Summary
        -------------------------------------------------------
        EXEC Reporting.usp_RebuildAssetSummary;


        -------------------------------------------------------
        -- 9. Rebuild Transaction Summary
        -------------------------------------------------------
        EXEC Reporting.usp_RebuildTransactionSummary;


        -------------------------------------------------------
        -- 10. Rebuild KPI Summary
        -------------------------------------------------------
        EXEC Reporting.usp_RebuildKpiSummary;


        -------------------------------------------------------
        -- 11. Rebuild KPI Trend
        -------------------------------------------------------
        EXEC Reporting.usp_RebuildKPITrend;

        --------------------------------------------------------
        ------12.Products
        ---------------------------------------------------------
        EXEC [Reporting].[usp_SyncProducts]


    END TRY

    BEGIN CATCH

        THROW;

    END CATCH
END;
GO
