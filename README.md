# CineZen iOS — App Nativa para iPhone / iPad

Contenedor nativo de streaming para iOS construido con SwiftUI y WebKit (`WKWebView`).

## Características de Blindaje Nativo (Apple WebKit)
1. **Sin Popups:** `createWebViewWith` devuelve `nil`, impidiendo que cualquier script abra ventanas emergentes o nuevas pestañas.
2. **Sin Secuestro de Pestaña:** `decidePolicyFor` bloquea cualquier redirección que intente salir del dominio oficial o abrir enlaces `itms-apps://`.
3. **Bloqueo de Red y CSS Nativo:** Compilado con `WKContentRuleList` de Apple para bloquear peticiones a ad-networks y ocultar capas trampa.
4. **Reproducción Directa sin Sandbox:** Carga el reproductor nativo directamente sin el atributo `sandbox` en HTML, permitiendo que el cliente negocie el video HLS a máxima velocidad sin errores de CORS ni carteles de *"Please Disable Sandbox"*.

---

## Cómo instalar en tu iPhone desde Windows (Sideloadly)

1. En GitHub, ve a la pestaña **Actions** y descarga el archivo `CineZen.ipa` generado en los artefactos de la compilación.
2. Abre **Sideloadly** en tu Windows (descárgalo gratis en https://sideloadly.io si no lo tienes).
3. Conecta tu iPhone a la PC con cable USB.
4. Arrastra el archivo `CineZen.ipa` a la ventana de Sideloadly.
5. Ingresa tu Apple ID (el personal gratuito).
6. Presiona **Start**. En 30 segundos la app estará instalada en tu iPhone.
7. En tu iPhone, ve a **Ajustes -> General -> VPN y gestión de dispositivos**, toca tu correo y selecciona **Confiar en esta app**. ¡Listo!
