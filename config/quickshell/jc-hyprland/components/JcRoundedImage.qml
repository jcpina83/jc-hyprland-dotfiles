import QtQuick
import QtQuick.Effects

Item {
    id: root

    property url source: ""
    property int radius: 8

    property int fillMode: Image.PreserveAspectCrop
    property bool asynchronous: true
    property bool cache: true

    property size sourceSize: Qt.size(0, 0)

    Image {
        id: sourceImage

        anchors.fill: parent

        source: root.source
        asynchronous: root.asynchronous
        cache: root.cache
        fillMode: root.fillMode
        sourceSize: root.sourceSize

        visible: false
    }

    Rectangle {
        id: imageMask

        anchors.fill: parent

        radius: root.radius
        color: "white"

        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent

        source: sourceImage

        maskEnabled: true
        maskSource: imageMask

        maskThresholdMin: 0.5
        maskSpreadAtMin: 1.0
    }
}
