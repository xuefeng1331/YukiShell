#include "wallfeed.h"

#include <QMutexLocker>
#include <QQmlEngine>
#include <cstring>

WallFeed::WallFeed(QObject *parent)
    : QObject(parent), m_sink(new QVideoSink(this))
{
    connect(m_sink, &QVideoSink::videoFrameChanged, m_sink, [this](const QVideoFrame &f) { onFrame(f); }, Qt::DirectConnection);
}

int WallFeed::watching() const
{
    int n = 0;
    for (bool playing : m_wants)
        if (playing) n++;
    return n;
}

QVideoFrame WallFeed::lastFrame() const
{
    QMutexLocker l(&m_lock);
    return m_last;
}

void WallFeed::want(const QString &key, bool playing)
{
    auto it = m_wants.find(key);
    if (it != m_wants.end() && it.value() == playing) return;
    m_wants.insert(key, playing);
    emit wantsChanged();
}

void WallFeed::release(const QString &key)
{
    if (m_wants.remove(key)) emit wantsChanged();
}

void WallFeed::clear()
{
    {
        QMutexLocker l(&m_lock);
        m_last = QVideoFrame();
    }
    if (m_hasFrame) {
        m_hasFrame = false;
        emit hasFrameChanged();
    }
}

void WallFeed::onFrame(const QVideoFrame &in)
{
    if (!in.isValid()) return;
    QVideoFrame out;
    if (in.handleType() == QVideoFrame::NoHandle) {
        out = in;
    } else {
        QVideoFrame src(in);
        if (!src.map(QVideoFrame::ReadOnly)) return;
        QVideoFrameFormat fmt(src.size(), src.pixelFormat());
        const QVideoFrameFormat sf = in.surfaceFormat();
        fmt.setColorSpace(sf.colorSpace());
        fmt.setColorTransfer(sf.colorTransfer());
        fmt.setColorRange(sf.colorRange());
        fmt.setStreamFrameRate(sf.streamFrameRate());
        out = QVideoFrame(fmt);
        if (!out.map(QVideoFrame::WriteOnly)) { src.unmap(); return; }
        for (int p = 0; p < src.planeCount() && p < out.planeCount(); ++p) {
            const int ib = src.bytesPerLine(p), ob = out.bytesPerLine(p);
            if (ib <= 0 || ob <= 0) continue;
            const int rows = std::min(src.mappedBytes(p) / ib, out.mappedBytes(p) / ob);
            const int len = std::min(ib, ob);
            const uchar *s = src.bits(p);
            uchar *d = out.bits(p);
            if (ib == ob) std::memcpy(d, s, size_t(rows) * size_t(ib));
            else for (int r = 0; r < rows; ++r) std::memcpy(d + size_t(r) * ob, s + size_t(r) * ib, size_t(len));
        }
        out.unmap();
        src.unmap();
        out.setStartTime(in.startTime());
        out.setEndTime(in.endTime());
    }
    out.setRotation(in.rotation());
    out.setMirrored(in.mirrored());
    {
        QMutexLocker l(&m_lock);
        m_last = out;
    }
    QMetaObject::invokeMethod(this, [this, out]() {
        if (!m_hasFrame) {
            m_hasFrame = true;
            emit hasFrameChanged();
        }
        emit frameReady(out);
    }, Qt::QueuedConnection);
}

WallFeedOutput::WallFeedOutput(QObject *parent) : QObject(parent) {}

void WallFeedOutput::componentComplete()
{
    if (QQmlEngine *e = qmlEngine(this))
        m_feed = e->singletonInstance<WallFeed *>("YukiVideo", "WallFeed");
    rewire();
}

void WallFeedOutput::setTarget(QObject *t)
{
    if (m_target == t) return;
    m_target = t;
    rewire();
    emit targetChanged();
}

void WallFeedOutput::setEnabled(bool on)
{
    if (m_enabled == on) return;
    m_enabled = on;
    rewire();
    emit enabledChanged();
}

void WallFeedOutput::rewire()
{
    disconnect(m_conn);
    m_conn = {};
    if (!m_feed || !m_target || !m_enabled) return;
    m_conn = connect(m_feed, &WallFeed::frameReady, this, &WallFeedOutput::push);
    if (m_feed->hasFrame()) push(m_feed->lastFrame());
}

void WallFeedOutput::push(const QVideoFrame &frame)
{
    if (auto *s = qobject_cast<QVideoSink *>(m_target.data()))
        s->setVideoFrame(frame);
}
