# 📍 flutter_gps_antigravity

> Aplicación móvil Flutter para rastreo GPS en tiempo real con soporte en segundo plano, visualización en mapa y registro histórico de ubicaciones.
<p align="center">
  <img width="1024" height="1024" alt="icon" src="https://github.com/user-attachments/assets/e63a2a17-36e1-44fb-a0de-dc389ed42e8f" />
</p>


> ✨ **Desarrollado con asistencia de [Antigravity](https://antigravity.dev)** — herramienta de IA para acelerar el desarrollo de software.

## Video demostrativo

El video cuenta con una duración de 3 minutos y se encuentra subido en la red social de Tiktok:

**Video:**
https://vt.tiktok.com/ZSCDfdtyR/
---

## Informe

En este informe se encuentra las comparaciones mejor organizadas:
https://docs.google.com/document/d/13bJAG8kSKy69kUsnu-6VIb6kkAE-Fg-A/edit?usp=sharing&ouid=102007950152418730246&rtpof=true&sd=true

---

## 📋 Descripción

**GPS Tracker** es una aplicación Android construida con Flutter que permite:

- Registrar la posición GPS de forma continua, incluso con la app en segundo plano
- Ver la ruta en tiempo real sobre un mapa OpenStreetMap.
- Consultar el historial completo de puntos capturados con velocidad, altitud y precisión
- Recibir notificaciones persistentes mientras el rastreo está activo

---

## 🚀 Funcionalidades

| Funcionalidad | Detalle |
|---|---|
| 🗺️ **Mapa en tiempo real** | Traza la ruta con polilínea verde sobre OpenStreetMap |
| 📡 **Rastreo en segundo plano** | Servicio foreground de Android que sobrevive al minimizar la app |
| 📊 **Panel de posición** | Latitud, longitud, velocidad (km/h), altitud (m) y precisión (±m) |
| 🕒 **Historial de registros** | Lista cronológica inversa con todos los puntos capturados |
| 📋 **Copiar coordenadas** | Un tap para copiar lat/lng al portapapeles |
| 🔔 **Notificación persistente** | Muestra la posición actual mientras el rastreo está activo |
| 🗑️ **Limpiar historial** | Elimina todos los registros con confirmación |

---

## 📸 Capturas de pantalla

> Las siguientes secciones muestran las pantallas principales de la aplicación en funcionamiento.

### 🗺️ Vista de Mapa
La pantalla de mapa muestra la ruta recorrida como una polilínea verde sobre OpenStreetMap. El marcador más grande indica la posición actual.
<p align="center">
  <img width="30%" alt="image" src="https://github.com/user-attachments/assets/043b15da-470f-4dcd-af91-74fbc0534bc2" />
</p>

### 🕒 Posiciones detectadas
<p align="center">
  <img width="30%" alt="image" src="https://github.com/user-attachments/assets/b237b0ca-f12b-44e3-a084-a2d45debb765" />
  <img width="30%" alt="image" src="https://github.com/user-attachments/assets/7f453656-3e3b-45c0-890e-9f8b8f2b1e57" />
</p>

### 🕒 Buscando ubicación
<p align="center">
  <img width="30%" alt="image" src="https://github.com/user-attachments/assets/7bab3f3b-3e32-4853-94d2-2c1c9011beae" />
</p>

### 🕒 Vista de Historial
Lista de todos los puntos GPS capturados, ordenados del más reciente al más antiguo.
<p align="center">
  <img width="30%" alt="image" src="https://github.com/user-attachments/assets/8fbf2621-8c4e-4aef-b5ca-dfa9b9e5f183" />
  <img width="30%" alt="image" src="https://github.com/user-attachments/assets/e332a7ee-20fc-4ac8-b263-bed2a911de5a" />
</p>

---

## 🏗️ Arquitectura

```
lib/
├── main.dart               
├── background_service.dart 
├── location_model.dart     
└── pages/
    ├── map_page.dart       
    └── history_page.dart   
```

---

## 📦 Dependencias principales

| Paquete | Versión | Uso |
|---|---|---|
| `geolocator` | ^13.0.2 | Stream de posición GPS |
| `flutter_background_service` | ^5.0.7 | Servicio foreground Android/iOS |
| `flutter_map` | ^7.0.2 | Mapa OpenStreetMap (sin API key) |
| `flutter_local_notifications` | ^19.4.2 | Notificación persistente de rastreo |
| `shared_preferences` | ^2.3.2 | Persistencia del historial GPS |
| `permission_handler` | ^11.3.1 | Permisos de ubicación y notificaciones |

---

## ⚙️ Requisitos

- Flutter `^3.12.1` / Dart `^3.12.1`
- Android 6.0+ (API 23) — se recomienda Android 10+ para ubicación en segundo plano

---

## 🛠️ Instalación y ejecución

```bash
# 1. Clonar el repositorio
git clone https://github.com/Kyara2005/flutter_gps_antigravity.git
cd flutter_gps_antigravity

# 2. Instalar dependencias
flutter pub get

# 3. Ejecutar en dispositivo/emulador
flutter run
```

> ⚠️ Para el rastreo en segundo plano en Android, el dispositivo debe tener habilitada la opción **"Permitir siempre"** en los permisos de ubicación de la app.
<p align="center".
  <img width="30%" alt="image" src="https://github.com/user-attachments/assets/fb0b78ba-f1f9-4293-9cdc-5b6a0a51b6f5" />
</p>

---

## 🔒 Permisos requeridos (Android)

| Permiso | Motivo |
|---|---|
| `ACCESS_FINE_LOCATION` | Obtener posición GPS precisa |
| `ACCESS_BACKGROUND_LOCATION` | Rastrear con la app en segundo plano |
| `FOREGROUND_SERVICE` | Mantener el servicio activo |
| `POST_NOTIFICATIONS` | Mostrar notificación persistente (Android 13+) |

---

## 🗺️ Mapa

La app utiliza **OpenStreetMap** a través de `flutter_map`. No requiere ninguna API key.

El centro inicial del mapa por defecto es **Quito, Ecuador** (`-0.2295, -78.5243`).

---

## 🤖 Desarrollado con Antigravity

Este proyecto fue construido con la asistencia de **[Antigravity](https://antigravity.dev)**, una herramienta de IA que acelera el desarrollo de software ayudando a analizar código, generar documentación, detectar bugs y proponer mejoras arquitectónicas.

Antigravity contribuyó en este proyecto con:

- Análisis completo de la arquitectura y flujo de datos
- Identificación de bugs.
