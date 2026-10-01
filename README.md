# szcore_billing

**SzCore Framework 1.4.0-rc1** · by **SzCode**

Player and society billing, invoice creation/payment/cancellation and invoice UI.

Dependencies: `oxmysql`, `szcore`, `szcore_society`, `szcore_ui`.

Public exports: `CreateBill`, `CreateBillForPlayer`, `PayBill`, `CancelBill`, `GetBills`, and client `OpenBilling`.

Invoice issuing is server-authoritative and can require on-duty job permissions and distance to the target player.
