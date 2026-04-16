#include "ConnectivityBackendPlugin.h"

#include "WifiController.h"

#include <qqml.h>

void ConnectivityBackendPlugin::registerTypes(const char *uri) {
    qmlRegisterSingletonType<WifiController>(
        uri,
        1,
        0,
        "WifiController",
        [](QQmlEngine *, QJSEngine *) -> QObject * {
            return new WifiController;
        }
    );

    qmlProtectModule(uri, 1);
}
