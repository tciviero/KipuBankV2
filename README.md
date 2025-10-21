Este contrato crea un banco multi-token que permite a direcciones depositar y retirar montos. A la vez le permite al creador del contrato consultar el saldo de cualquier direccion. Los retiros son seguros y siguen convenciones de seguridad.

Para desplegar el contrato se necesita proporcionar el valor de dos parametros, el primero es para determinar el limite total de eth que puede guardar el banco, y el otro para determinar el limite maximo que se puede retirar por transaccion.

Mejoras:

-Soporte multi-token: Ahora incluye activos ERC-20, ademas de ETH, permitiendo ampliar la utilidad del banco para que no sea solo para usuarios de ETH.

-Estandarización a 6 Decimales: Todos los saldos internos se gestionan en 6 decimales para simplificar la contabilidad multi-token.

-BankCap con Oracle: El límite de depósito de ETH se verifica convirtiendo el total de ETH a USD usando Chainlink, esto asegura que se utiliza el valor actual de ETH, usando una fuente confiable y segura.

-Control de acceso con OpenZeppelin: El uso de esta librería confiada por millones permite asegurarnos que el código de seguridad no presenta errores y a la vez permite facilmente ver como fueron implementadas las medidas de seguridad al reconocer las interfaces de OpenZeppelin utilizadas.

-Patron Circuit Breaker: se usa con la libreria de OpenZeppelin para ante cualquier comportamiento anómalo se puede deter el funcionamiento del banco hasta terminar con la investigación.
