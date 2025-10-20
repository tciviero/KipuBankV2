Este contrato crea un banco de eth que permite a direcciones depositar y retirar montos. A la vez le permite al creador del contrato consultar el saldo de cualquier direccion. Los retiros de eth son seguros y siguen convenciones de seguridad.

Para desplegar el contrato se necesita proporcionar el valor de dos parametros, el primero es para determinar el limite total de eth que puede guardar el banco, y el otro para determinar el limite de eth que se puede retirar por transaccion.

Se puede interactuar de varias formas con el banco, ya sea mediante las funciones depositar(), withdraw() y getSaldo(), asi como enviando directamente el eth, ya que el contrato implementa receive() y fallback() para correctamente responder a cualquier envio de eth.
