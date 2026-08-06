package funkin.ui.debug.charting.commands;

#if FEATURE_CHART_EDITOR
import funkin.data.song.SongData.SongEventData;
import funkin.data.song.SongData.SongNoteData;
import funkin.data.song.SongDataUtils;

/**
 * Duplicate the given notes and events, placing the copies at the given offset (in time and columns).
 * Unlike MoveItemsCommand, the originals are left untouched; only the new copies are added.
 *
 * Used by the mobile "long-press and drag" gesture. See DuplicateNotesCommand for details.
 */
@:nullSafety
@:access(funkin.ui.debug.charting.ChartEditorState)
class DuplicateItemsCommand implements ChartEditorCommand
{
  var sourceNotes:Array<SongNoteData>;
  var duplicatedNotes:Array<SongNoteData>;
  var sourceEvents:Array<SongEventData>;
  var duplicatedEvents:Array<SongEventData>;
  var offset:Float;
  var columns:Int;

  public function new(sourceNotes:Array<SongNoteData>, sourceEvents:Array<SongEventData>, offset:Float, columns:Int, offsetInSteps:Bool = false)
  {
    this.sourceNotes = [for (note in sourceNotes) note.clone()];
    this.sourceEvents = [for (event in sourceEvents) event.clone()];
    if (offsetInSteps) this.offset = Conductor.instance.getStepTimeInMs(offset);
    else
      this.offset = offset;
    this.columns = columns;
    this.duplicatedNotes = [];
    this.duplicatedEvents = [];
  }

  /**
   * Perform the action, duplicating the notes and events into the chart.
   *
   * @param state The ChartEditorState to perform the command on.
   */
  public function execute(state:ChartEditorState):Void
  {
    // Clear any leftover ghost/drag-preview offset on the ORIGINAL notes/events before we move
    // the selection over to the new duplicates, or their sprites will visually stick at the drag
    // position. See `clearDragGhostOverrides` for details.
    state.clearDragGhostOverrides();

    duplicatedNotes = [];
    duplicatedEvents = [];

    for (note in sourceNotes)
    {
      var resultNote = note.clone();
      resultNote.time = (resultNote.time + offset).clamp(0, Conductor.instance.getStepTimeInMs(state.songLengthInSteps - (1 * state.noteSnapRatio)));
      resultNote.data = ChartEditorState.gridColumnToNoteData((ChartEditorState.noteDataToGridColumn(resultNote.data) + columns).clamp(0,
        ChartEditorState.STRUMLINE_SIZE * 2 - 1));

      duplicatedNotes.push(resultNote);
    }

    for (event in sourceEvents)
    {
      var resultEvent = event.clone();
      resultEvent.time = (resultEvent.time + offset).clamp(0, Conductor.instance.getStepTimeInMs(state.songLengthInSteps - (1 * state.noteSnapRatio)));

      duplicatedEvents.push(resultEvent);
    }

    // Note: the originals are intentionally left in place, unmodified.
    state.currentSongChartNoteData = state.currentSongChartNoteData.concat(duplicatedNotes);
    state.currentSongChartEventData = state.currentSongChartEventData.concat(duplicatedEvents);
    state.currentNoteSelection = duplicatedNotes;
    state.currentEventSelection = duplicatedEvents;

    state.playSound(Paths.sound('ui/editors/chart-editor/charting-sounds/note-place'));

    state.saveDataDirty = true;
    state.noteDisplayDirty = true;
    state.notePreviewDirty = true;
    state.editButtonsDirty = true;

    state.sortChartData();
  }

  /**
   * Reverse the action, removing the duplicated notes and events.
   *
   * @param state The ChartEditorState to perform the command on.
   */
  public function undo(state:ChartEditorState):Void
  {
    state.currentSongChartNoteData = SongDataUtils.subtractNotes(state.currentSongChartNoteData, duplicatedNotes);
    state.currentSongChartEventData = SongDataUtils.subtractEvents(state.currentSongChartEventData, duplicatedEvents);

    state.currentNoteSelection = sourceNotes;
    state.currentEventSelection = sourceEvents;

    state.playSound(Paths.sound('ui/editors/chart-editor/charting-sounds/undo'));

    state.saveDataDirty = true;
    state.noteDisplayDirty = true;
    state.notePreviewDirty = true;
    state.editButtonsDirty = true;

    state.sortChartData();
  }

  /**
   * Whether the command should display in the undo/redo menu.
   * This should be `false` if no real actions were actually performed.
   *
   * @param state The ChartEditorState to perform the command on.
   * @return Whether the command should be added to the history.
   */
  public function shouldAddToHistory(state:ChartEditorState):Bool
  {
    return (sourceNotes.length > 0 || sourceEvents.length > 0);
  }

  /**
   * Convert the action to a string. Used to display the action in the undo/redo history.
   * @return This command, as a readable string.
   */
  public function toString():String
  {
    var len:Int = sourceNotes.length + sourceEvents.length;
    return 'Duplicate $len Items';
  }
}
#end
