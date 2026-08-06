package funkin.ui.debug.charting.commands;

#if FEATURE_CHART_EDITOR
import funkin.data.song.SongData.SongNoteData;
import funkin.data.song.SongDataUtils;

/**
 * Duplicate the given notes, placing the copies at the given offset (in time and columns).
 * Unlike MoveNotesCommand, the original notes are left untouched; only the new copies are added.
 *
 * Used by the mobile "long-press and drag" gesture, which lets touch users duplicate a selection
 * without a keyboard: long-pressing an already-selected note arms duplicate mode, and dragging
 * then places copies wherever the finger is released.
 */
@:nullSafety
@:access(funkin.ui.debug.charting.ChartEditorState)
class DuplicateNotesCommand implements ChartEditorCommand
{
  var sourceNotes:Array<SongNoteData>;
  var duplicatedNotes:Array<SongNoteData>;
  var offset:Float;
  var columns:Int;

  public function new(sourceNotes:Array<SongNoteData>, offset:Float, columns:Int, offsetInSteps:Bool = false)
  {
    // Clone the notes so later edits to the original selection don't affect this command's history.
    this.sourceNotes = [for (note in sourceNotes) note.clone()];
    if (offsetInSteps) this.offset = Conductor.instance.getStepTimeInMs(offset);
    else
      this.offset = offset;
    this.columns = columns;
    this.duplicatedNotes = [];
  }

  /**
   * Perform the action, duplicating the notes into the chart.
   *
   * @param state The ChartEditorState to perform the command on.
   */
  public function execute(state:ChartEditorState):Void
  {
    // Clear any leftover ghost/drag-preview offset on the ORIGINAL notes before we move the
    // selection over to the new duplicates, or their sprites will visually stick at the drag
    // position. See `clearDragGhostOverrides` for details.
    state.clearDragGhostOverrides();

    duplicatedNotes = [];

    for (note in sourceNotes)
    {
      var resultNote = note.clone();
      resultNote.time = (resultNote.time + offset).clamp(0, Conductor.instance.getStepTimeInMs(state.songLengthInSteps - (1 * state.noteSnapRatio)));
      resultNote.data = ChartEditorState.gridColumnToNoteData((ChartEditorState.noteDataToGridColumn(resultNote.data) + columns).clamp(0,
        ChartEditorState.STRUMLINE_SIZE * 2 - 1));

      duplicatedNotes.push(resultNote);
    }

    // Note: the original notes are intentionally left in currentSongChartNoteData, unmodified.
    state.currentSongChartNoteData = state.currentSongChartNoteData.concat(duplicatedNotes);
    state.currentNoteSelection = duplicatedNotes;

    state.playSound(Paths.sound('ui/editors/chart-editor/charting-sounds/note-place'));

    state.saveDataDirty = true;
    state.noteDisplayDirty = true;
    state.notePreviewDirty = true;
    state.editButtonsDirty = true;

    state.sortChartData();
  }

  /**
   * Reverse the action, removing the duplicated notes.
   *
   * @param state The ChartEditorState to perform the command on.
   */
  public function undo(state:ChartEditorState):Void
  {
    state.currentSongChartNoteData = SongDataUtils.subtractNotes(state.currentSongChartNoteData, duplicatedNotes);

    state.currentNoteSelection = sourceNotes;

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
    return (sourceNotes.length > 0);
  }

  /**
   * Convert the action to a string. Used to display the action in the undo/redo history.
   * @return This command, as a readable string.
   */
  public function toString():String
  {
    var len:Int = sourceNotes.length;
    return 'Duplicate $len Notes';
  }
}
#end
