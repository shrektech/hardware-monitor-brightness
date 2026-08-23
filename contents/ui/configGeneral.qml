import QtQuick 2.15
import QtQuick.Controls 2.15 as QQC2
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents3

Kirigami.FormLayout {
    id: page

    property alias cfg_stepSize: stepSizeSpin.value
    property alias cfg_showPercentage: showPercentageCheck.checked
    property alias cfg_showIndividualSliders: showIndividualCheck.checked
    property alias cfg_invertScroll: invertScrollCheck.checked

    QQC2.SpinBox {
        id: stepSizeSpin
        Kirigami.FormData.label: i18n("Adjustment step size (%):")
        from: 1
        to: 25
        stepSize: 1
    }

    PlasmaComponents3.CheckBox {
        id: showPercentageCheck
        Kirigami.FormData.label: i18n("Panel display:")
        text: i18n("Show brightness percentage badge next to taskbar icon")
    }

    PlasmaComponents3.CheckBox {
        id: showIndividualCheck
        Kirigami.FormData.label: i18n("Popup layout:")
        text: i18n("Show individual monitor sliders below master slider")
    }

    PlasmaComponents3.CheckBox {
        id: invertScrollCheck
        Kirigami.FormData.label: i18n("Mouse wheel:")
        text: i18n("Invert mouse wheel scroll direction")
    }
}
