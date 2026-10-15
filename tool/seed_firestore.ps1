# Seed script to populate Cloud Firestore 'products' collection via REST API
$apiKey = "AIzaSyAjUpUYWOA0Pgg1CLDcL52odu-UOp9jmRs"
$baseUrl = "https://firestore.googleapis.com/v1/projects/appizza-restaurant/databases/(default)/documents/products?key=$apiKey"

$products = @(
  @{
    name = "Pizza Pepperoni Clásica"
    description = "Masa artesanal crujiente, salsa pomodoro italiana, abundante queso mozzarella y generosas rodajas de pepperoni americano premium."
    price = 36000.0
    categoria = "pizza"
    pizza_size = "Mediana (8 porciones)"
    stock = 50
    available = $true
    imageUrl = "https://images.unsplash.com/photo-1628840042765-356cda07504e?w=800&auto=format&fit=crop&q=80"
  },
  @{
    name = "Pizza Margherita Tradicional"
    description = "La auténtica receta napolitana con salsa de tomates San Marzano, mozzarella di bufala fresca, albahaca recién cosechada y aceite de oliva virgen extra."
    price = 34000.0
    categoria = "pizza"
    pizza_size = "Mediana (8 porciones)"
    stock = 40
    available = $true
    imageUrl = "https://images.unsplash.com/photo-1604382355076-af4b0eb60143?w=800&auto=format&fit=crop&q=80"
  },
  @{
    name = "Pizza Hawaiana Especial"
    description = "Equilibrio perfecto de dulce y salado: jamón york artesanal ahumado, trozos de piña caramelizada al horno y doble capa de queso mozzarella."
    price = 38000.0
    categoria = "pizza"
    pizza_size = "Mediana (8 porciones)"
    stock = 45
    available = $true
    imageUrl = "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=800&auto=format&fit=crop&q=80"
  },
  @{
    name = "Pizza Cuatro Quesos Gourmet"
    description = "Fusión irresistible para amantes del queso: mozzarella fundida, queso provolone ahumado, gorgonzola azul y virutas de parmesano reggiano."
    price = 42000.0
    categoria = "pizza"
    pizza_size = "Mediana (8 porciones)"
    stock = 35
    available = $true
    imageUrl = "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=800&auto=format&fit=crop&q=80"
  },
  @{
    name = "Pizza BBQ Pollo & Tocino"
    description = "Tiras de pechuga de pollo marinadas a la parrilla, tocineta crujiente ahumada, cebolla roja caramelizada y abundante salsa barbacoa dulce."
    price = 44000.0
    categoria = "pizza"
    pizza_size = "Mediana (8 porciones)"
    stock = 40
    available = $true
    imageUrl = "https://images.unsplash.com/photo-1594007654729-407eedc4be65?w=800&auto=format&fit=crop&q=80"
  },
  @{
    name = "Pizza Vegetariana del Huerto"
    description = "Champiñones frescos salteados, pimentón asado, maíz tierno, rodajas de tomate maduro, aceitunas negras y suave orégano silvestre."
    price = 35000.0
    categoria = "pizza"
    pizza_size = "Mediana (8 porciones)"
    stock = 30
    available = $true
    imageUrl = "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=800&auto=format&fit=crop&q=80"
  },
  @{
    name = "Pizza Carnes Supremas"
    description = "La favorita para carnívoros: carne boloñesa sazonada, rodajas de pepperoni, jamón ahumado, tocineta crocante y salchicha italiana."
    price = 46000.0
    categoria = "pizza"
    pizza_size = "Mediana (8 porciones)"
    stock = 35
    available = $true
    imageUrl = "https://images.unsplash.com/photo-1588315029754-2dd089d39a1a?w=800&auto=format&fit=crop&q=80"
  },
  @{
    name = "Pizza Champiñones & Jamón Trufado"
    description = "Champiñones París salteados en ajo suave, jamón selecto, base blanca cremosa con queso mozzarella y aroma a hierbas finas."
    price = 39000.0
    categoria = "pizza"
    pizza_size = "Mediana (8 porciones)"
    stock = 35
    available = $true
    imageUrl = "https://images.unsplash.com/photo-1534308983496-4fabb1a015ee?w=800&auto=format&fit=crop&q=80"
  },
  @{
    name = "Coca-Cola Original 400ml"
    description = "Gaseosa helada en botella de 400ml, el acompañamiento tradicional y burbujeante perfecto para cualquier pizza."
    price = 6000.0
    categoria = "bebida"
    pizza_size = "400ml"
    stock = 60
    available = $true
    imageUrl = "https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=800&auto=format&fit=crop&q=80"
  },
  @{
    name = "Sprite Lima-Limón 400ml"
    description = "Refresco burbujeante y transparente con intenso sabor a lima-limón, servido bien frío con hielo."
    price = 6000.0
    categoria = "bebida"
    pizza_size = "400ml"
    stock = 45
    available = $true
    imageUrl = "https://images.unsplash.com/photo-1625772299848-391b6a87d7b3?w=800&auto=format&fit=crop&q=80"
  },
  @{
    name = "Limonada de Coco Frappé"
    description = "Bebida insignia caribeña preparada al instante con crema de coco natural, jugo de limón fresco y textura frappé granizada."
    price = 10500.0
    categoria = "bebida"
    pizza_size = "500ml"
    stock = 30
    available = $true
    imageUrl = "https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=800&auto=format&fit=crop&q=80"
  },
  @{
    name = "Jugo Natural de Maracuyá"
    description = "Zumo 100% natural de maracuyá colombiano, refrescante acidez tropical preparado con hielo picado."
    price = 8500.0
    categoria = "bebida"
    pizza_size = "450ml"
    stock = 35
    available = $true
    imageUrl = "https://images.unsplash.com/photo-1621506289937-a8e4df240d0b?w=800&auto=format&fit=crop&q=80"
  },
  @{
    name = "Malteada de Chocolate & Vainilla"
    description = "Cremosa malteada artesanal preparada con helado premium de vainilla, sirope de chocolate oscuro, crema chantilly y chispas."
    price = 12000.0
    categoria = "bebida"
    pizza_size = "450ml"
    stock = 30
    available = $true
    imageUrl = "https://images.unsplash.com/photo-1572490122747-3968b75cc699?w=800&auto=format&fit=crop&q=80"
  },
  @{
    name = "Cerveza Artesanal Golden Ale"
    description = "Cerveza rubia tipo Golden Ale artesanal bien fría, con 4.8% ABV, refrescante y con suaves notas a malta y trigo."
    price = 13000.0
    categoria = "bebida"
    pizza_size = "330ml"
    stock = 40
    available = $true
    imageUrl = "https://images.unsplash.com/photo-1608270104169-792823631623?w=800&auto=format&fit=crop&q=80"
  },
  @{
    name = "Agua Mineral con Gas 500ml"
    description = "Agua mineral pura de manantial con delicadas burbujas, servida fría con rodaja de limón fresca opcional."
    price = 5000.0
    categoria = "bebida"
    pizza_size = "500ml"
    stock = 50
    available = $true
    imageUrl = "https://images.unsplash.com/photo-1560023907-5f339617ea30?w=800&auto=format&fit=crop&q=80"
  }
)

Write-Host "Consultando productos existentes en Firestore..."
$existingDocs = @{}
try {
  $getRes = Invoke-RestMethod -Uri "$baseUrl&pageSize=100" -Method Get
  if ($getRes.documents) {
    foreach ($doc in $getRes.documents) {
      $nameVal = $doc.fields.name.stringValue
      if ($nameVal) {
        $existingDocs[$nameVal.ToLower().Trim()] = $doc.name
      }
    }
  }
} catch {
  Write-Host "Error consultando existentes: $_"
}

$pizzasCount = 0
$bebidasCount = 0

foreach ($p in $products) {
  $payload = @{
    fields = @{
      name = @{ stringValue = $p.name }
      description = @{ stringValue = $p.description }
      price = @{ doubleValue = [double]$p.price }
      categoria = @{ stringValue = $p.categoria }
      pizza_size = @{ stringValue = $p.pizza_size }
      stock = @{ integerValue = [string]$p.stock }
      available = @{ booleanValue = $p.available }
      imageUrl = @{ stringValue = $p.imageUrl }
    }
  } | ConvertTo-Json -Depth 5

  $normName = $p.name.ToLower().Trim()
  if ($existingDocs.ContainsKey($normName)) {
    $docPath = $existingDocs[$normName]
    $updateUrl = "https://firestore.googleapis.com/v1/$docPath`?key=$apiKey"
    Write-Host "Actualizando: $($p.name)..."
    Invoke-RestMethod -Uri $updateUrl -Method Patch -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) -ContentType "application/json; charset=utf-8" | Out-Null
  } else {
    Write-Host "Creando: $($p.name)..."
    Invoke-RestMethod -Uri $baseUrl -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) -ContentType "application/json; charset=utf-8" | Out-Null
  }

  if ($p.categoria -eq "pizza") { $pizzasCount++ }
  if ($p.categoria -eq "bebida") { $bebidasCount++ }
}

Write-Host "-------------------------------------------"
Write-Host "SEED COMPLETADO CON ÉXITO:"
Write-Host "Total productos cargados: $($products.Count)"
Write-Host "Pizzas: $pizzasCount"
Write-Host "Bebidas: $bebidasCount"
Write-Host "-------------------------------------------"
