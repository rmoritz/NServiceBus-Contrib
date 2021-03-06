--------------------------------------------------------------------
-- Remove any existing objects for the sample.
--------------------------------------------------------------------

IF EXISTS (SELECT *
           FROM sys.services
           WHERE name = 'ServiceA')
BEGIN
    DROP SERVICE ServiceA ;
END ;
GO

IF OBJECT_ID('[dbo].[ServiceAQueue]') IS NOT NULL AND
   EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID('[dbo].[ServiceAQueue]')
            AND type = 'SQ')
BEGIN
    DROP QUEUE [dbo].[ServiceAQueue] ;
END ;
GO

IF EXISTS (SELECT *
           FROM sys.services
           WHERE name = 'ServiceB')
BEGIN
    DROP SERVICE ServiceB ;
END ;
GO

IF OBJECT_ID('[dbo].[ServiceBQueue]') IS NOT NULL AND
   EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID('[dbo].[ServiceBQueue]')
            AND type = 'SQ')
BEGIN
    DROP QUEUE [dbo].[ServiceBQueue] ;
END ;
GO

IF EXISTS (SELECT *
           FROM sys.services
           WHERE name = 'ErrorService')
BEGIN
    DROP SERVICE ErrorService ;
END ;
GO

IF OBJECT_ID('[dbo].[ErrorServiceQueue]') IS NOT NULL AND
   EXISTS(SELECT *
          FROM sys.objects
          WHERE object_id = OBJECT_ID('[dbo].[ErrorServiceQueue]')
            AND type = 'SQ')
BEGIN
    DROP QUEUE [dbo].[ErrorServiceQueue] ;
END ;
GO

IF EXISTS (SELECT *
           FROM sys.service_contracts
           WHERE name = 'NServiceBusTransportMessageContract')
BEGIN
    DROP CONTRACT NServiceBusTransportMessageContract ;
END ;
GO

IF EXISTS (SELECT *
           FROM sys.service_message_types
           WHERE name = 'NServiceBusTransportMessage')
BEGIN
    DROP MESSAGE TYPE NServiceBusTransportMessage ;
END ;
GO

IF EXISTS (SELECT *
           FROM sys.procedures
           WHERE name = 'SendNServiceBusMessage')
BEGIN
    DROP PROCEDURE SendNServiceBusMessage
END ;
GO

--------------------------------------------------------------------
-- Create objects for the sample.
--------------------------------------------------------------------

CREATE MESSAGE TYPE NServiceBusTransportMessage
    VALIDATION = NONE ;
GO

CREATE CONTRACT NServiceBusTransportMessageContract
    ( NServiceBusTransportMessage SENT BY ANY);
GO

-- Services

CREATE QUEUE [dbo].[ServiceAQueue];
GO

CREATE SERVICE ServiceA
    ON QUEUE [dbo].[ServiceAQueue]
    (NServiceBusTransportMessageContract);
GO

--CREATE QUEUE [dbo].[ServiceBQueue] WITH
--	POISON_MESSAGE_HANDLING ( STATUS = OFF );
CREATE QUEUE [dbo].[ServiceBQueue];
GO

CREATE SERVICE ServiceB
    ON QUEUE [dbo].[ServiceBQueue]
    (NServiceBusTransportMessageContract);
GO

--CREATE QUEUE [dbo].[ErrorServiceQueue] WITH
--	POISON_MESSAGE_HANDLING ( STATUS = OFF );
CREATE QUEUE [dbo].[ErrorServiceQueue];
GO

CREATE SERVICE ErrorService
    ON QUEUE [dbo].[ErrorServiceQueue]
    (NServiceBusTransportMessageContract);
GO

-- Stored Procedures

CREATE PROCEDURE [dbo].[SendNServiceBusMessage]
    @TargetService NVARCHAR(250),
    @MessageNamespace NVARCHAR(500),
    @MessageName NVARCHAR(250),
    @MessageContent NVARCHAR(4000)
AS
 
BEGIN
    -- Sending a Service Broker Message
    DECLARE @InitDlgHandle UNIQUEIDENTIFIER;
    DECLARE @MessageContract NVARCHAR(200);
    DECLARE @MessageType NVARCHAR(200);
    DECLARE @TransportMessage NVARCHAR(4000);
    DECLARE @MessageId UNIQUEIDENTIFIER;
 
    SET NOCOUNT ON

    SET @MessageId = NEWID(); 
    SET  @MessageContract = 'NServiceBusTransportMessageContract';
    SET  @MessageType = 'NServiceBusTransportMessage';
 
    BEGIN TRANSACTION;
        BEGIN DIALOG @InitDlgHandle
            FROM SERVICE @TargetService
            TO SERVICE @TargetService
            ON CONTRACT @MessageContract
            WITH ENCRYPTION = OFF;
 
        SET @TransportMessage ='<?xml version="1.0" encoding="utf-16"?><TransportMessage><Id>'
        + CONVERT(NVARCHAR(MAX), @MessageId) + '</Id><Body><![CDATA[<Messages xmlns="http://tempuri.net/'
        + @MessageNamespace + '"><' + @MessageName+ '>' + @MessageContent 
        + '</'+@MessageName + '></Messages>]]></Body></TransportMessage>';
 
        SEND ON CONVERSATION @InitDlgHandle
            MESSAGE TYPE @MessageType
            (@TransportMessage);
 
    COMMIT TRANSACTION;
END
GO
