//! Deliver Keyboard Events In Order And Report Missed Input

const Event = @import("shared").keyboard.types.event.Event;
const Queue = @import("keyboard").types.service.queue.Queue;

pub fn push(queue: *Queue, event: Event) void {
    if (queue.Count == queue.Events.len) lost(queue);
    queue.Events[(queue.Head + queue.Count) % queue.Events.len] = event;
    queue.Count += 1;
}

pub fn take(queue: *Queue) ?Event {
    if (queue.Count == 0) return null;
    const result = queue.Events[queue.Head];
    queue.Head = (queue.Head + 1) % queue.Events.len;
    queue.Count -= 1;
    return result;
}

pub fn lost(queue: *Queue) void {
    queue.Head = 0;
    queue.Count = 0;
    queue.Lost = true;
}
