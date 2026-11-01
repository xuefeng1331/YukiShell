#pragma once
#include <QHash>
#include <QMetaObject>
#include <QMutex>
#include <QObject>
#include <QPointer>
#include <QVideoFrame>
#include <QVideoSink>
#include <QtQml/qqmlparserstatus.h>
#include <QtQml/qqmlregistration.h>

class WallFeed : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QObject *sink READ sink CONSTANT)
    Q_PROPERTY(bool hasFrame READ hasFrame NOTIFY hasFrameChanged)
    Q_PROPERTY(int watching READ watching NOTIFY wantsChanged)
    Q_PROPERTY(int holding READ holding NOTIFY wantsChanged)
public:
    explicit WallFeed(QObject *parent = nullptr);
    QObject *sink() const { return m_sink; }
    bool hasFrame() const { return m_hasFrame; }
    int watching() const;
    int holding() const { return m_wants.size(); }
    QVideoFrame lastFrame() const;

    Q_INVOKABLE void want(const QString &key, bool playing);
    Q_INVOKABLE void release(const QString &key);
    Q_INVOKABLE void clear();

signals:
    void frameReady(const QVideoFrame &frame);
    void hasFrameChanged();
    void wantsChanged();

private:
    void onFrame(const QVideoFrame &frame);
    QVideoSink *m_sink;
    mutable QMutex m_lock;
    QVideoFrame m_last;
    bool m_hasFrame = false;
    QHash<QString, bool> m_wants;
};

class WallFeedOutput : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
    QML_ELEMENT
    Q_PROPERTY(QObject *target READ target WRITE setTarget NOTIFY targetChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
public:
    explicit WallFeedOutput(QObject *parent = nullptr);
    QObject *target() const { return m_target; }
    void setTarget(QObject *t);
    bool enabled() const { return m_enabled; }
    void setEnabled(bool on);
    void classBegin() override {}
    void componentComplete() override;

signals:
    void targetChanged();
    void enabledChanged();

private:
    void rewire();
    void push(const QVideoFrame &frame);
    QPointer<WallFeed> m_feed;
    QPointer<QObject> m_target;
    bool m_enabled = true;
    QMetaObject::Connection m_conn;
};
